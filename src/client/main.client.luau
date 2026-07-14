local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BlindOverlay = require(script.Parent.UI.BlindOverlay)
local LobbyScreen = require(script.Parent.UI.LobbyScreen)
local ResultsScreen = require(script.Parent.UI.ResultsScreen)

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

Remotes.RoundStarted.OnClientEvent:Connect(function(data)
	LobbyScreen.hide()
	if data.role == Config.ROLE_BLIND then
		BlindOverlay.show()
	else
		showGuideLabel()
	end
end)

Remotes.RoundEnded.OnClientEvent:Connect(function(data)
	BlindOverlay.hide()
	hideGuideLabel()
	ResultsScreen.show(data)
end)

LobbyScreen.show()

print("Client started")
