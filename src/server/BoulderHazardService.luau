local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local BoulderHazardService = {}

-- Hazard tuning (not shared gameplay constants, so kept local to this file)
local FIRE_INTERVAL_MIN = 4
local FIRE_INTERVAL_MAX = 7
local LAUNCH_SPEED = 45
local ROCK_LIFETIME = 20

local WAIT_TIMEOUT = 10

local ramp = Workspace:WaitForChild("BoulderRamp", WAIT_TIMEOUT)
if not ramp then
	warn("BoulderHazardService: Workspace.BoulderRamp not found within "
		.. WAIT_TIMEOUT .. "s — hazard disabled")
	return BoulderHazardService
end

local cannons = {}
for _, name in { "Cannon1", "Cannon2", "Cannon3" } do
	local cannon = ramp:WaitForChild(name, WAIT_TIMEOUT)
	if cannon then
		table.insert(cannons, cannon)
	else
		warn("BoulderHazardService: BoulderRamp." .. name .. " not found — that cannon is disabled")
	end
end

local rockTemplateSource = ramp:WaitForChild("Rock", WAIT_TIMEOUT)
if not rockTemplateSource then
	warn("BoulderHazardService: BoulderRamp.Rock not found within " .. WAIT_TIMEOUT .. "s — hazard disabled")
	return BoulderHazardService
end

-- Reparent the template out of Workspace so it isn't itself a live hazard;
-- :Clone() still works on an instance that isn't parented anywhere.
local rockTemplate = rockTemplateSource
rockTemplate.Parent = ServerStorage

-- Rock might be a single BasePart or a multi-part Model (e.g. an imported
-- mesh asset) — handle both rather than assuming one.
local function primaryPartOf(instance: Instance): BasePart?
	if instance:IsA("BasePart") then
		return instance
	elseif instance:IsA("Model") then
		return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function tryKill(hit: BasePart)
	local character = hit.Parent
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = 0
	end
end

local function fireCannon(cannon: BasePart)
	local rock = rockTemplate:Clone()
	local primary = primaryPartOf(rock)
	if not primary then
		warn("BoulderHazardService: Rock template has no BasePart to launch")
		rock:Destroy()
		return
	end

	if rock:IsA("Model") then
		rock:PivotTo(cannon.CFrame)
	else
		rock.CFrame = cannon.CFrame
	end
	rock.Parent = Workspace

	local parts = rock:IsA("BasePart") and { rock } or rock:GetDescendants()
	for _, part in parts do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = true
		end
	end

	primary.AssemblyLinearVelocity = cannon.CFrame.LookVector * LAUNCH_SPEED

	local connections: { RBXScriptConnection } = {}
	local function onTouched(hit: BasePart)
		if CollectionService:HasTag(hit, Config.BOULDER_DESPAWN_TAG) then
			for _, connection in connections do
				connection:Disconnect()
			end
			rock:Destroy()
			return
		end
		tryKill(hit)
	end

	for _, part in parts do
		if part:IsA("BasePart") then
			table.insert(connections, part.Touched:Connect(onTouched))
		end
	end

	-- Safety net in case a rock gets stuck and never reaches the despawn tag
	task.delay(ROCK_LIFETIME, function()
		if rock.Parent then
			for _, connection in connections do
				connection:Disconnect()
			end
			rock:Destroy()
		end
	end)
end

local function startCannonLoop(cannon: BasePart)
	task.spawn(function()
		task.wait(math.random() * FIRE_INTERVAL_MAX) -- stagger the three cannons
		while true do
			local ok, err = pcall(fireCannon, cannon)
			if not ok then
				warn("BoulderHazardService: fireCannon failed for " .. cannon:GetFullName() .. " - " .. tostring(err))
			end
			task.wait(FIRE_INTERVAL_MIN + math.random() * (FIRE_INTERVAL_MAX - FIRE_INTERVAL_MIN))
		end
	end)
end

for _, cannon in cannons do
	startCannonLoop(cannon :: BasePart)
end

return BoulderHazardService
