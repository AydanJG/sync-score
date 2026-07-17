local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local CameraLink = {}

local broadcastConnection: RBXScriptConnection? = nil
local receiveConnection: RBXScriptConnection? = nil

-- Blind player side: streams this client's camera CFrame to the server every
-- frame so RoundService can relay it to the guide. Fire-and-forget over an
-- UnreliableRemoteEvent -- a dropped frame just gets overwritten by the next
-- one, no need for reliable delivery on a value this high-frequency.
function CameraLink.startBroadcasting()
	if broadcastConnection then
		return
	end
	broadcastConnection = RunService.Heartbeat:Connect(function()
		Remotes.CameraSync:FireServer(Workspace.CurrentCamera.CFrame)
	end)
end

-- Guide side: takes over this client's camera and snaps it to whatever
-- CFrame the blind player last broadcast, so the guide sees exactly what the
-- blind player would see.
function CameraLink.startReceiving()
	if receiveConnection then
		return
	end
	Workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
	receiveConnection = Remotes.CameraSync.OnClientEvent:Connect(function(cframe: CFrame)
		Workspace.CurrentCamera.CFrame = cframe
	end)
end

-- Stops whichever mode is active and restores normal camera control. Safe to
-- call unconditionally (e.g. on every RoundEnded) regardless of which role
-- this client had.
function CameraLink.stop()
	if broadcastConnection then
		broadcastConnection:Disconnect()
		broadcastConnection = nil
	end
	if receiveConnection then
		receiveConnection:Disconnect()
		receiveConnection = nil
		Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	end
end

return CameraLink
