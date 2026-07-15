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

local ramp = Workspace:WaitForChild("BoulderRamp")
local cannons = {
	ramp:WaitForChild("Cannon1"),
	ramp:WaitForChild("Cannon2"),
	ramp:WaitForChild("Cannon3"),
}

-- Reparent the template out of Workspace so it isn't itself a live hazard;
-- :Clone() still works on an instance that isn't parented anywhere.
local rockTemplate = ramp:WaitForChild("Rock") :: BasePart
rockTemplate.Parent = ServerStorage

local function tryKill(hit: BasePart)
	local character = hit.Parent
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = 0
	end
end

local function fireCannon(cannon: BasePart)
	local rock = rockTemplate:Clone()
	rock.Anchored = false
	rock.CanCollide = true
	rock.CFrame = cannon.CFrame
	rock.Parent = Workspace
	rock.AssemblyLinearVelocity = cannon.CFrame.LookVector * LAUNCH_SPEED

	local connection: RBXScriptConnection
	connection = rock.Touched:Connect(function(hit: BasePart)
		if CollectionService:HasTag(hit, Config.BOULDER_DESPAWN_TAG) then
			connection:Disconnect()
			rock:Destroy()
			return
		end
		tryKill(hit)
	end)

	-- Safety net in case a rock gets stuck and never reaches the despawn tag
	task.delay(ROCK_LIFETIME, function()
		if rock.Parent then
			connection:Disconnect()
			rock:Destroy()
		end
	end)
end

local function startCannonLoop(cannon: BasePart)
	task.spawn(function()
		task.wait(math.random() * FIRE_INTERVAL_MAX) -- stagger the three cannons
		while true do
			fireCannon(cannon)
			task.wait(FIRE_INTERVAL_MIN + math.random() * (FIRE_INTERVAL_MAX - FIRE_INTERVAL_MIN))
		end
	end)
end

for _, cannon in cannons do
	startCannonLoop(cannon :: BasePart)
end

return BoulderHazardService
