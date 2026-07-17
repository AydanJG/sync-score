local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WAIT_TIMEOUT = 10

-- Every script in this game requires this module, directly or indirectly
-- (RoundService/PairingService pull it in via require chains) — an
-- unbounded WaitForChild here doesn't just fail this module, it hangs
-- main.server.luau's require() call forever, silently preventing every
-- later require (hazards, etc.) from ever running. Timeout + warn instead
-- of hanging, so a missing/out-of-sync remote is loud, not silent.
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", WAIT_TIMEOUT)
if not remotesFolder then
	warn("Remotes: ReplicatedStorage.Remotes not found within " .. WAIT_TIMEOUT .. "s — is the Rojo plugin connected and synced?")
end

local function getRemote(name: string): Instance?
	local remote = remotesFolder and remotesFolder:WaitForChild(name, WAIT_TIMEOUT)
	if not remote then
		warn(
			"Remotes: ReplicatedStorage.Remotes."
				.. name
				.. " not found within "
				.. WAIT_TIMEOUT
				.. "s — check default.project.json matches this Studio session (Rojo resync needed?)"
		)
	end
	return remote
end

local Remotes = {
	RoundStarted = getRemote("RoundStarted") :: RemoteEvent,
	RoundEnded = getRemote("RoundEnded") :: RemoteEvent,
	CameraSync = getRemote("CameraSync") :: UnreliableRemoteEvent,
	RequestGameStart = getRemote("RequestGameStart") :: RemoteEvent,
	GameStarting = getRemote("GameStarting") :: RemoteEvent,
	PairingCountdown = getRemote("PairingCountdown") :: RemoteEvent,
}

return Remotes
