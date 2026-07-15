local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Knockback = require(script.Parent.Knockback)

local RotatingLogService = {}

-- Hazard tuning (not shared gameplay constants, so kept local to this file)
local SPIN_SPEED = 90 -- degrees per second
-- World-space axis (world up), not the log's own local axis — see
-- LogGateService for why local axes on asset-pack Models are unreliable.
local SPIN_AXIS = Vector3.new(0, 1, 0)
local KNOCKBACK_FORCE = 100
local KNOCKBACK_UPWARD = 35
local KNOCKBACK_DURATION = 0.8 -- seconds PlatformStand stays on so physics carries the knockback
local KNOCKBACK_COOLDOWN = 1 -- seconds before the same character can be knocked back again
local WAIT_TIMEOUT = 10

local blindObby = Workspace:WaitForChild("BlindObby", WAIT_TIMEOUT)
if not blindObby then
	warn("RotatingLogService: Workspace.BlindObby not found within " .. WAIT_TIMEOUT .. "s — hazard disabled")
	return RotatingLogService
end

local rotatingLog = blindObby:WaitForChild("Rotating Log", WAIT_TIMEOUT)
if not rotatingLog then
	warn('RotatingLogService: BlindObby."Rotating Log" not found — hazard disabled')
	return RotatingLogService
end

-- Kinematic, scripted motion — anchor everything so physics doesn't fight
-- the scripted rotation.
for _, part in rotatingLog:GetDescendants() do
	if part:IsA("BasePart") then
		part.Anchored = true
	end
end
if rotatingLog:IsA("BasePart") then
	rotatingLog.Anchored = true
end

-- Rotates around its own center (not an external pivot like LogGateService)
-- — the center point is whatever GetPivot() reports, which for a Model
-- without PrimaryPart is a computed bounding-box center, close enough for
-- a sweeping floor obstacle.
local centerPosition = (rotatingLog :: PVInstance):GetPivot().Position
local currentCFrame = (rotatingLog :: PVInstance):GetPivot()

-- Per-character cooldown since continued contact during a sweep could
-- otherwise trigger repeated Touched events.
local lastKnockbackAt = {}
local function knockback(hit: BasePart)
	local character = hit.Parent
	if not character then
		return
	end

	local now = os.clock()
	if lastKnockbackAt[character] and now - lastKnockbackAt[character] < KNOCKBACK_COOLDOWN then
		return
	end
	lastKnockbackAt[character] = now

	Knockback.apply(hit, centerPosition, KNOCKBACK_FORCE, KNOCKBACK_UPWARD, KNOCKBACK_DURATION)
end

local parts = rotatingLog:IsA("BasePart") and { rotatingLog } or rotatingLog:GetDescendants()
for _, part in parts do
	if part:IsA("BasePart") then
		part.Touched:Connect(knockback)
	end
end

-- Continuous horizontal sweep — no easing/pause, just a steady spin.
RunService.Heartbeat:Connect(function(dt: number)
	local delta = CFrame.fromAxisAngle(SPIN_AXIS, math.rad(SPIN_SPEED * dt))
	currentCFrame = CFrame.new(centerPosition) * delta * CFrame.new(-centerPosition) * currentCFrame
	if rotatingLog:IsA("Model") then
		(rotatingLog :: Model):PivotTo(currentCFrame)
	else
		(rotatingLog :: BasePart).CFrame = currentCFrame
	end
end)

return RotatingLogService
