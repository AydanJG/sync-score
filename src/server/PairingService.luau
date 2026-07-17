local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RoundService = require(script.Parent.RoundService)

local PairingService = {}

-- Pairing-pad tuning (implementation detail, not shared gameplay pacing,
-- so kept local rather than in Config.luau).
local POLL_INTERVAL = 0.25
local PROMPT_HOLD_DURATION = 0.5
local PROMPT_MAX_DISTANCE = 10
local DETECTION_HEIGHT = 6 -- studs above the pad's surface a standing player reliably falls within

-- Per-pad live state, keyed by the pad's detection BasePart.
local padOccupants: { [BasePart]: { Player } } = {}
local padClosed: { [BasePart]: boolean } = {}
local padPrompts: { [BasePart]: ProximityPrompt } = {}
local padStatusLabels: { [BasePart]: TextLabel } = {}

-- Pad instances might be asset-pack Models without a reliable single Part
-- (same pattern as Rock/Cannon1-3/GateTop elsewhere in this codebase) —
-- resolve to one BasePart to use for overlap detection and the prompt.
local function padPartOf(instance: Instance): BasePart?
	if instance:IsA("BasePart") then
		return instance
	elseif instance:IsA("Model") then
		return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

-- A pad that isn't Anchored will fall/drift under gravity, silently
-- breaking overlap detection without ever erroring — same class of bug
-- that hit the Boulder Cannon spawn markers earlier in this project. Warn
-- loudly instead.
local function warnIfUnanchored(instance: Instance)
	if instance:IsA("BasePart") and not instance.Anchored then
		warn("PairingService: " .. instance:GetFullName() .. " is not Anchored — set Anchored = true in Studio.")
	elseif instance:IsA("Model") then
		for _, descendant in instance:GetDescendants() do
			if descendant:IsA("BasePart") and not descendant.Anchored then
				warn("PairingService: " .. descendant:GetFullName() .. " is not Anchored — set Anchored = true in Studio.")
			end
		end
	end
end

local function getCharacterPlayer(part: BasePart): Player?
	local character = part.Parent
	if character and character:FindFirstChildOfClass("Humanoid") then
		return Players:GetPlayerFromCharacter(character)
	end
	return nil
end

-- A standing character rests on TOP of a (likely thin) pad's surface
-- rather than meaningfully inside its volume, so checking overlap against
-- the pad's own geometry (GetPartsInPart) flickers on/off with ordinary
-- physics jitter — this is what caused the occupant count to flash
-- between 0 and 1. Checking a taller invisible zone above the pad's
-- surface instead reliably catches a standing character regardless of
-- that jitter.
local function findOccupants(padPart: BasePart): { Player }
	local detectionSize = Vector3.new(padPart.Size.X, DETECTION_HEIGHT, padPart.Size.Z)
	local detectionCFrame = padPart.CFrame * CFrame.new(0, padPart.Size.Y / 2 + DETECTION_HEIGHT / 2, 0)

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { padPart }

	local seen: { [Player]: boolean } = {}
	local occupants: { Player } = {}
	for _, part in Workspace:GetPartBoundsInBox(detectionCFrame, detectionSize, overlapParams) do
		local player = getCharacterPlayer(part)
		-- Players already mid-round are physically elsewhere on the shared
		-- course, but exclude them defensively rather than assume that.
		if player and not seen[player] and not RoundService.isPlayerInRound(player) then
			seen[player] = true
			table.insert(occupants, player)
		end
	end
	return occupants
end

local function resetPad(padPart: BasePart)
	padOccupants[padPart] = {}
	padClosed[padPart] = false
	local prompt = padPrompts[padPart]
	if prompt then
		prompt.Enabled = false
		prompt.ActionText = "Close Pad"
	end
	local label = padStatusLabels[padPart]
	if label then
		label.Text = "0/2"
	end
end

-- Pairs off whoever was standing on this pad when the lobby timer expired.
-- Shuffling before pairing consecutively handles both cases uniformly:
-- exactly 2 (a closed pad, or an open pad with exactly 2) just get paired,
-- more than 2 get randomly paired off, and a leftover from an odd count
-- just waits for the next cycle.
local function formPairsFromPad(padPart: BasePart)
	local occupants = padOccupants[padPart]
	if not occupants or #occupants < 2 then
		return
	end

	for i = #occupants, 2, -1 do
		local j = math.random(1, i)
		occupants[i], occupants[j] = occupants[j], occupants[i]
	end

	local i = 1
	while i + 1 <= #occupants do
		local p1, p2 = occupants[i], occupants[i + 1]
		if p1.Parent and p2.Parent then
			RoundService.startRound(p1, p2)
		end
		i += 2
	end
end

local function setupPad(instance: Instance)
	local padPart = padPartOf(instance)
	if not padPart then
		warn("PairingService: pairing pad " .. instance:GetFullName() .. " has no BasePart to use for detection")
		return
	end
	warnIfUnanchored(instance)

	padOccupants[padPart] = {}
	padClosed[padPart] = false

	-- Floats above the pad and replicates automatically like any other
	-- Workspace instance — no remote needed to make occupancy visible.
	-- Sized in studs (the Scale component of a BillboardGui's Size, unlike
	-- a ScreenGui's, is a stud measurement) rather than pure pixel Offset —
	-- an Offset-only size doesn't shrink/grow like a normal world object,
	-- which is what caused it to look larger the farther away it was.
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PadStatus"
	billboard.Size = UDim2.new(3, 0, 1, 0)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.MaxDistance = 40
	billboard.AlwaysOnTop = true
	billboard.Parent = padPart

	local card = Instance.new("Frame")
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
	card.BackgroundTransparency = 0.2
	card.BorderSizePixel = 0
	card.Parent = billboard

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0.3, 0)
	cardCorner.Parent = card

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = Color3.fromRGB(60, 120, 255)
	cardStroke.Thickness = 2
	cardStroke.Transparency = 0.1
	cardStroke.Parent = card

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.fromScale(0.85, 0.7)
	statusLabel.Position = UDim2.fromScale(0.5, 0.5)
	statusLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	statusLabel.BackgroundTransparency = 1
	statusLabel.TextColor3 = Color3.new(1, 1, 1)
	statusLabel.TextScaled = true
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.Text = "0/2"
	statusLabel.Parent = card
	padStatusLabels[padPart] = statusLabel

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Close Pad"
	prompt.ObjectText = "Pairing Pad"
	prompt.HoldDuration = PROMPT_HOLD_DURATION
	prompt.MaxActivationDistance = PROMPT_MAX_DISTANCE
	prompt.Enabled = false
	prompt.Parent = padPart
	padPrompts[padPart] = prompt

	-- Lets 2 players who already know who they want to pair with lock in
	-- early, so a 3rd player can't jump on the pad and get randomly mixed
	-- into their pairing before the lobby timer expires.
	prompt.Triggered:Connect(function(player)
		local occupants = padOccupants[padPart]
		if padClosed[padPart] or not occupants or #occupants ~= 2 then
			return
		end

		local isOccupant = false
		for _, occupant in occupants do
			if occupant == player then
				isOccupant = true
				break
			end
		end
		if not isOccupant then
			return
		end

		padClosed[padPart] = true
		prompt.Enabled = false
		prompt.ActionText = "Closed"
		local label = padStatusLabels[padPart]
		if label then
			label.Text = "Locked (2/2)"
		end
	end)
end

for _, instance in CollectionService:GetTagged(Config.PAIRING_PAD_TAG) do
	setupPad(instance)
end

-- Occupancy is polled rather than tracked via Touched/TouchEnded — a
-- player has multiple limbs that can touch/leave independently, which
-- makes "is this player still standing here" bookkeeping unreliable via
-- those events. A closed pad's roster is frozen (not re-polled) until the
-- lobby timer processes and resets it.
task.spawn(function()
	while true do
		for padPart, closed in padClosed do
			if not closed then
				local occupants = findOccupants(padPart)
				padOccupants[padPart] = occupants

				local prompt = padPrompts[padPart]
				if prompt then
					prompt.Enabled = #occupants == 2
				end

				local label = padStatusLabels[padPart]
				if label then
					label.Text = #occupants .. "/2"
				end
			end
		end
		task.wait(POLL_INTERVAL)
	end
end)

-- One lobby-wide countdown rather than a per-pad timer — whoever is on a
-- pad (or locked it via the ProximityPrompt above) when it expires gets
-- paired, then every pad resets for the next cycle. Broadcasts every
-- second (rather than once per cycle) since, unlike the Start Game
-- countdown, this cycle repeats continuously and players can arrive
-- mid-cycle — a client can't reconstruct "time remaining" on its own, the
-- server has to keep telling it.
task.spawn(function()
	while true do
		for remaining = Config.PAIRING_TIMER_DURATION, 1, -1 do
			Remotes.PairingCountdown:FireAllClients(remaining)
			task.wait(1)
		end
		for padPart in padClosed do
			formPairsFromPad(padPart)
			resetPad(padPart)
		end
	end
end)

return PairingService
