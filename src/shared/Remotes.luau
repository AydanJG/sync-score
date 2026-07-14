local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")

local Remotes = {
	RoundStarted = remotesFolder:WaitForChild("RoundStarted") :: RemoteEvent,
	RoundEnded = remotesFolder:WaitForChild("RoundEnded") :: RemoteEvent,
	RequestPairing = remotesFolder:WaitForChild("RequestPairing") :: RemoteEvent,
}

return Remotes
