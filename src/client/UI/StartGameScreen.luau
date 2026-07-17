local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local StartGameScreen = {}

-- Shared visual language across this file's elements.
local ACCENT_COLOR = Color3.fromRGB(60, 120, 255)
local PANEL_COLOR = Color3.fromRGB(18, 20, 28)

local screenGui: ScreenGui? = nil
local button: TextButton? = nil
local countdownPanel: Frame? = nil
local countdownLabel: TextLabel? = nil

local function build(): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "StartGameScreen"
	gui.ResetOnSpawn = false

	local startButton = Instance.new("TextButton")
	startButton.Name = "StartButton"
	startButton.AnchorPoint = Vector2.new(0.5, 0.5)
	startButton.Position = UDim2.fromScale(0.5, 0.85)
	startButton.Size = UDim2.fromOffset(240, 56)
	startButton.BackgroundColor3 = ACCENT_COLOR
	startButton.TextColor3 = Color3.new(1, 1, 1)
	startButton.TextSize = 24
	startButton.Font = Enum.Font.GothamBold
	startButton.Text = "Start Game"
	startButton.AutoButtonColor = true
	startButton.Parent = gui

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 12)
	buttonCorner.Parent = startButton

	local buttonStroke = Instance.new("UIStroke")
	buttonStroke.Color = Color3.new(1, 1, 1)
	buttonStroke.Transparency = 0.7
	buttonStroke.Thickness = 1.5
	buttonStroke.Parent = startButton

	startButton.MouseButton1Click:Connect(function()
		Remotes.RequestGameStart:FireServer()
	end)
	button = startButton

	local panel = Instance.new("Frame")
	panel.Name = "CountdownPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.4)
	panel.Size = UDim2.fromOffset(160, 160)
	panel.BackgroundColor3 = PANEL_COLOR
	panel.BackgroundTransparency = 0.25
	panel.Visible = false
	panel.Parent = gui
	countdownPanel = panel

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0.5, 0)
	panelCorner.Parent = panel

	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = ACCENT_COLOR
	panelStroke.Thickness = 3
	panelStroke.Transparency = 0.15
	panelStroke.Parent = panel

	local label = Instance.new("TextLabel")
	label.Name = "CountdownLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.Parent = panel
	countdownLabel = label

	return gui
end

function StartGameScreen.show()
	if not screenGui then
		screenGui = build()
		screenGui.Parent = player:WaitForChild("PlayerGui")
	end
	screenGui.Enabled = true
	if button then
		button.Visible = true
	end
	if countdownPanel then
		countdownPanel.Visible = false
	end
end

function StartGameScreen.hide()
	if screenGui then
		screenGui.Enabled = false
	end
end

-- The server fires GameStarting once, then does its own identical-duration
-- wait before actually teleporting everyone -- running the visible
-- countdown locally (rather than over a tick-by-tick remote) keeps this
-- closely in sync with the server's teleport without extra networking.
function StartGameScreen.runCountdown(duration: number)
	if not screenGui then
		StartGameScreen.show()
	end
	if button then
		button.Visible = false
	end
	if not countdownPanel or not countdownLabel then
		return
	end
	countdownPanel.Visible = true

	task.spawn(function()
		for remaining = duration, 1, -1 do
			countdownLabel.Text = tostring(remaining)
			task.wait(1)
		end
		StartGameScreen.hide()
	end)
end

Remotes.GameStarting.OnClientEvent:Connect(function(duration: number)
	StartGameScreen.runCountdown(duration)
end)

return StartGameScreen
