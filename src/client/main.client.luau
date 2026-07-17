local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BlindOverlay = require(script.Parent.UI.BlindOverlay)
local StartGameScreen = require(script.Parent.UI.StartGameScreen)
local PairingCountdownScreen = require(script.Parent.UI.PairingCountdownScreen)
local ResultsScreen = require(script.Parent.UI.ResultsScreen)
local CameraLink = require(script.Parent.CameraLink)

local player = Players.LocalPlayer

local guideLabel: TextLabel? = nil

local function showGuideLabel()
	if guideLabel then
		guideLabel.Visible = true
		return
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "GuideHUD"
	screenGui.ResetOnSpawn = false

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 0.08)
	label.Position = UDim2.fromScale(0, 0)
	label.BackgroundTransparency = 0.4
	label.BackgroundColor3 = Color3.new(0, 0, 0)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = "You're guiding - help your partner reach the goal"
	label.Parent = screenGui

	screenGui.Parent = player:WaitForChild("PlayerGui")
	guideLabel = label
end

local function hideGuideLabel()
	if guideLabel then
		guideLabel.Visible = false
	end
end

-- The Match Room's pairing-pad countdown is a separate, continuously
-- repeating cycle from the Start Game countdown -- once Start Game's own
-- countdown finishes (the moment LobbyService will have teleported this
-- client into the Match Room), start showing it.
Remotes.GameStarting.OnClientEvent:Connect(function(duration: number)
	task.delay(duration, function()
		PairingCountdownScreen.start()
	end)
end)

Remotes.RoundStarted.OnClientEvent:Connect(function(data)
	StartGameScreen.hide()
	PairingCountdownScreen.stop()
	if data.role == Config.ROLE_BLIND then
		BlindOverlay.show()
		CameraLink.startBroadcasting()
	else
		showGuideLabel()
		CameraLink.startReceiving()
	end
end)

Remotes.RoundEnded.OnClientEvent:Connect(function(data)
	BlindOverlay.hide()
	hideGuideLabel()
	CameraLink.stop()
	ResultsScreen.show(data)
end)

StartGameScreen.show()

print("Client started")
