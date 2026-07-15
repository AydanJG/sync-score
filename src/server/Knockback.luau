local Knockback = {}

-- Roblox's Humanoid controller actively resists external velocity every
-- frame, so a plain impulse is barely noticeable — briefly disabling the
-- humanoid's own movement control (PlatformStand) lets physics actually
-- carry the knockback, then control is handed back after it settles.
-- Cooldown tracking (if wanted) is the caller's responsibility, not this
-- module's — different hazards shouldn't share cooldown state.
function Knockback.apply(hit: BasePart, sourcePosition: Vector3, force: number, upward: number, duration: number)
	local character = hit.Parent
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (humanoid and rootPart) then
		return
	end

	-- Flattened to horizontal only — otherwise whatever vertical offset
	-- happens to exist between the player and the hazard at the moment of
	-- contact partially cancels the `upward` component below, making the
	-- launch weaker/less consistent than the tuned numbers suggest.
	local rawDirection = rootPart.Position - sourcePosition
	local awayDirection = Vector3.new(rawDirection.X, 0, rawDirection.Z)
	if awayDirection.Magnitude < 0.1 then
		awayDirection = Vector3.new(math.random(-10, 10), 0, math.random(-10, 10))
	end
	awayDirection = awayDirection.Unit

	humanoid.PlatformStand = true
	rootPart.AssemblyLinearVelocity = awayDirection * force + Vector3.new(0, upward, 0)

	task.delay(duration, function()
		if humanoid.Parent then
			humanoid.PlatformStand = false
		end
	end)
end

return Knockback
