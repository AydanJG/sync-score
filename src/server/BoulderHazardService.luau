local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local BoulderHazardService = {}

-- Hazard tuning (not shared gameplay constants, so kept local to this file)
local FIRE_INTERVAL_MIN = 4
local FIRE_INTERVAL_MAX = 7
local LAUNCH_SPEED = 45
local LAUNCH_DIRECTION = Vector3.new(0, 0, 1) -- world +Z, down the ramp
local SPAWN_OFFSET = 5 -- studs in front of the spawn marker, along LAUNCH_DIRECTION
local ROCK_LIFETIME = 20
local WAIT_TIMEOUT = 10
local KNOCKBACK_FORCE = 60
local KNOCKBACK_UPWARD = 25
local KNOCKBACK_DURATION = 0.6 -- seconds PlatformStand stays on so physics carries the knockback

-- A spawn marker that isn't Anchored will fall/drift under gravity, and
-- since its position is read live each time it fires, that silently
-- breaks spawn positioning without ever erroring. Warn loudly instead.
local function warnIfUnanchored(name: string, instance: Instance)
	if instance:IsA("BasePart") and not instance.Anchored then
		warn("BoulderHazardService: Workspace." .. name .. " is not Anchored — it will fall/drift and break spawn positioning. Set Anchored = true in Studio.")
	elseif instance:IsA("Model") then
		for _, descendant in instance:GetDescendants() do
			if descendant:IsA("BasePart") and not descendant.Anchored then
				warn("BoulderHazardService: Workspace." .. name .. "." .. descendant.Name .. " is not Anchored — it will fall/drift and break spawn positioning. Set Anchored = true in Studio.")
			end
		end
	end
end

local spawnPoints = {}
for _, name in { "RockSpawn1", "RockSpawn2", "RockSpawn3" } do
	local spawnPoint = Workspace:WaitForChild(name, WAIT_TIMEOUT)
	if spawnPoint then
		warnIfUnanchored(name, spawnPoint)
		table.insert(spawnPoints, spawnPoint)
	else
		warn("BoulderHazardService: Workspace." .. name .. " not found — that spawn is disabled")
	end
end

local rockTemplate = ServerStorage:WaitForChild("Rock", WAIT_TIMEOUT)
if not rockTemplate then
	warn("BoulderHazardService: ServerStorage.Rock not found within " .. WAIT_TIMEOUT .. "s — hazard disabled")
	return BoulderHazardService
end

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

-- Touched always fires with the specific Part that was hit, but the
-- despawn tag might be applied to a parent Model (e.g. if the platform
-- is a multi-part asset-pack Model and the whole Model got tagged) —
-- walk up the ancestry rather than checking only the exact touched part.
local function isDespawnZone(hit: BasePart): boolean
	local instance: Instance? = hit
	while instance do
		if CollectionService:HasTag(instance, Config.BOULDER_DESPAWN_TAG) then
			return true
		end
		instance = instance.Parent
	end
	return false
end

-- Roblox's Humanoid controller actively resists external velocity every
-- frame, so a plain impulse is barely noticeable — briefly disabling the
-- humanoid's own movement control (PlatformStand) lets physics actually
-- carry the knockback, then control is handed back after it settles.
local function knockback(hit: BasePart, impactPosition: Vector3)
	local character = hit.Parent
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (humanoid and rootPart) then
		return
	end

	local awayDirection = rootPart.Position - impactPosition
	if awayDirection.Magnitude < 0.1 then
		awayDirection = Vector3.new(math.random(-10, 10), 0, math.random(-10, 10))
	end
	awayDirection = awayDirection.Unit

	humanoid.PlatformStand = true
	rootPart.AssemblyLinearVelocity = awayDirection * KNOCKBACK_FORCE + Vector3.new(0, KNOCKBACK_UPWARD, 0)

	task.delay(KNOCKBACK_DURATION, function()
		if humanoid.Parent then
			humanoid.PlatformStand = false
		end
	end)
end

local function fireFrom(spawnPoint: Instance)
	local rock = rockTemplate:Clone()
	local primary = primaryPartOf(rock)
	if not primary then
		warn("BoulderHazardService: Rock template has no BasePart to launch")
		rock:Destroy()
		return
	end

	local spawnCFrame = (spawnPoint :: PVInstance):GetPivot() + LAUNCH_DIRECTION * SPAWN_OFFSET

	if rock:IsA("Model") then
		rock:PivotTo(spawnCFrame)
	else
		rock.CFrame = spawnCFrame
	end
	rock.Parent = Workspace

	local parts = rock:IsA("BasePart") and { rock } or rock:GetDescendants()
	for _, part in parts do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = true
			-- If the model's parts aren't already rigidly connected, weld
			-- every part to primary so the whole rock always moves as one
			-- assembly — otherwise unanchoring + setting velocity on just
			-- primary can leave other parts behind to fall independently.
			if part ~= primary then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = primary
				weld.Part1 = part
				weld.Parent = primary
			end
		end
	end

	primary.AssemblyLinearVelocity = LAUNCH_DIRECTION * LAUNCH_SPEED

	-- Launch sound — parented to the rock itself, so it plays positionally
	-- from the launch point and gets cleaned up automatically whenever the
	-- rock is destroyed (despawn zone or lifetime safety net), no separate
	-- cleanup needed.
	local launchSound = Instance.new("Sound")
	launchSound.Name = "LaunchSound"
	launchSound.SoundId = "rbxassetid://125205557479599"
	launchSound.Volume = 0.4
	launchSound.Parent = primary
	launchSound:Play()

	local connections: { RBXScriptConnection } = {}
	local function onTouched(hit: BasePart)
		if isDespawnZone(hit) then
			for _, connection in connections do
				connection:Disconnect()
			end
			rock:Destroy()
			return
		end
		knockback(hit, primary.Position)
	end

	for _, part in parts do
		if part:IsA("BasePart") then
			table.insert(connections, part.Touched:Connect(onTouched))
		end
	end

	-- Once the rock is actually rolling on the ramp, contact with an
	-- irregular mesh shape imparts sideways drift/spin that a one-time
	-- launch velocity can't prevent — cancel any sideways (X) velocity
	-- every frame so it only ever travels straight down the ramp (Z).
	table.insert(
		connections,
		RunService.Heartbeat:Connect(function()
			local velocity = primary.AssemblyLinearVelocity
			if velocity.X ~= 0 then
				primary.AssemblyLinearVelocity = Vector3.new(0, velocity.Y, velocity.Z)
			end
		end)
	)

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

-- One shared loop picking a random spawn point each time, rather than an
-- independent timer per spawn point — guarantees only one rock is ever
-- launched at a time, so two cannons can't overlap.
if #spawnPoints > 0 then
	task.spawn(function()
		while true do
			local spawnPoint = spawnPoints[math.random(1, #spawnPoints)]
			-- TEMPORARY debug print — remove once the spawn-location issue
			-- is confirmed/fixed. Shows exactly which marker fires and
			-- where, every cycle.
			local pivot = (spawnPoint :: PVInstance):GetPivot()
			print(
				"BoulderHazardService: firing from "
					.. spawnPoint.Name
					.. " at "
					.. tostring(pivot.Position)
			)
			local ok, err = pcall(fireFrom, spawnPoint)
			if not ok then
				warn("BoulderHazardService: fireFrom failed for " .. spawnPoint:GetFullName() .. " - " .. tostring(err))
			end
			task.wait(FIRE_INTERVAL_MIN + math.random() * (FIRE_INTERVAL_MAX - FIRE_INTERVAL_MIN))
		end
	end)
end

return BoulderHazardService
