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
local LAUNCH_DIRECTION = Vector3.new(0, 0, 1) -- world +Z, down the ramp
local SPAWN_OFFSET = 5 -- studs in front of the spawn marker, along LAUNCH_DIRECTION
local ROCK_LIFETIME = 20
local WAIT_TIMEOUT = 10

local spawnPoints = {}
for _, name in { "RockSpawn1", "RockSpawn2", "RockSpawn3" } do
	local spawnPoint = Workspace:WaitForChild(name, WAIT_TIMEOUT)
	if spawnPoint then
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

local function tryKill(hit: BasePart)
	local character = hit.Parent
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = 0
	end
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
		end
	end

	primary.AssemblyLinearVelocity = LAUNCH_DIRECTION * LAUNCH_SPEED

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

local function startSpawnLoop(spawnPoint: Instance)
	task.spawn(function()
		task.wait(math.random() * FIRE_INTERVAL_MAX) -- stagger the three spawns
		while true do
			local ok, err = pcall(fireFrom, spawnPoint)
			if not ok then
				warn("BoulderHazardService: fireFrom failed for " .. spawnPoint:GetFullName() .. " - " .. tostring(err))
			end
			task.wait(FIRE_INTERVAL_MIN + math.random() * (FIRE_INTERVAL_MAX - FIRE_INTERVAL_MIN))
		end
	end)
end

for _, spawnPoint in spawnPoints do
	startSpawnLoop(spawnPoint)
end

return BoulderHazardService
