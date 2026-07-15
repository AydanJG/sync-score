local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LogGateService = {}

-- Hazard tuning (not shared gameplay constants, so kept local to this file)
-- Swings symmetrically around the rest position (assumed to be hanging
-- straight down from GateTop, wherever LogStructure was placed in
-- Studio) — +/- HALF_SWING degrees, like a real playground swing, never
-- rising above the post.
local HALF_SWING = 60 -- degrees each side of rest (120 total arc)
local SWING_DURATION = 1.6 -- seconds per half-swing
local PAUSE_DURATION = 0.4 -- seconds paused at each extreme before reversing
-- World-space axis, NOT GateTop's local axis — GateTop is likely a
-- Model without PrimaryPart set (same asset-pack pattern seen elsewhere
-- this session), which makes its local orientation unreliable. A fixed
-- world axis sidesteps that. Try Vector3.new(0, 0, 1) if this is wrong.
local SWING_AXIS = Vector3.new(1, 0, 0)
local KNOCKBACK_FORCE = 55
local KNOCKBACK_UPWARD = 20
local KNOCKBACK_DURATION = 0.6 -- seconds PlatformStand stays on so physics carries the knockback
local KNOCKBACK_COOLDOWN = 1 -- seconds before the same character can be knocked back again
local WAIT_TIMEOUT = 10

local gate = Workspace:WaitForChild("Log Gate", WAIT_TIMEOUT)
if not gate then
	warn('LogGateService: Workspace."Log Gate" not found within ' .. WAIT_TIMEOUT .. "s — hazard disabled")
	return LogGateService
end

local logStructure = gate:WaitForChild("LogStructure", WAIT_TIMEOUT)
local gateTop = gate:WaitForChild("GateTop", WAIT_TIMEOUT)
if not (logStructure and gateTop) then
	warn('LogGateService: LogStructure or GateTop not found under "Log Gate" — hazard disabled')
	return LogGateService
end

if not logStructure:IsA("Model") then
	warn("LogGateService: LogStructure is not a Model — hazard disabled")
	return LogGateService
end

-- Kinematic, scripted motion — anchor everything so physics doesn't fight
-- the scripted pivot animation.
for _, part in logStructure:GetDescendants() do
	if part:IsA("BasePart") then
		part.Anchored = true
	end
end

local originalCFrame = logStructure:GetPivot()
-- Only the pivot's position is used (not its rotation) — rotation happens
-- around a fixed world axis instead, see SWING_AXIS above.
local pivotPosition = (gateTop :: PVInstance):GetPivot().Position

-- Rotates LogStructure around the external GateTop pivot point (not its
-- own center) by `angle` degrees from its original rest orientation.
local function setAngle(angle: number)
	local delta = CFrame.fromAxisAngle(SWING_AXIS, math.rad(angle))
	logStructure:PivotTo(CFrame.new(pivotPosition) * delta * CFrame.new(-pivotPosition) * originalCFrame)
end

-- Knockback — same PlatformStand technique as BoulderHazardService: the
-- Humanoid controller otherwise resists external velocity every frame.
local lastKnockbackAt = {}
local function knockback(hit: BasePart)
	local character = hit.Parent
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (humanoid and rootPart and character) then
		return
	end

	local now = os.clock()
	if lastKnockbackAt[character] and now - lastKnockbackAt[character] < KNOCKBACK_COOLDOWN then
		return
	end
	lastKnockbackAt[character] = now

	local logPosition = logStructure:GetPivot().Position
	local awayDirection = rootPart.Position - logPosition
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

for _, part in logStructure:GetDescendants() do
	if part:IsA("BasePart") then
		part.Touched:Connect(knockback)
	end
end

-- Swing loop: -HALF_SWING -> +HALF_SWING -> -HALF_SWING -> ..., eased like
-- a pendulum (fast through the middle, slow approaching each extreme)
-- with a brief explicit pause at each end before reversing.
task.spawn(function()
	local currentAngle = -HALF_SWING
	local targetAngle = HALF_SWING
	while true do
		local startAngle = currentAngle
		local startTime = os.clock()
		while true do
			local alpha = math.clamp((os.clock() - startTime) / SWING_DURATION, 0, 1)
			local eased = TweenService:GetValue(alpha, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			setAngle(startAngle + (targetAngle - startAngle) * eased)
			if alpha >= 1 then
				break
			end
			RunService.Heartbeat:Wait()
		end
		currentAngle = targetAngle
		targetAngle = -targetAngle
		task.wait(PAUSE_DURATION)
	end
end)

return LogGateService
