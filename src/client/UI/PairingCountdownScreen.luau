local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local PairingCountdownScreen = {}

-- Matches StartGameScreen's visual language.
local ACCENT_COLOR = Color3.fromRGB(60, 120, 255)
local PANEL_COLOR = Color3.fromRGB(18, 20, 28)

local screenGui: ScreenGui? = nil
local label: TextLabel? = nil
local active = false

local function build(): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "PairingCountdownScreen"
	gui.ResetOnSpawn = false

	local panel = Instance.new("Frame")
	panel.Name = "CountdownPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.fromScale(0.5, 0.03)
	panel.Size = UDim2.fromOffset(300, 48)
	panel.BackgroundColor3 = PANEL_COLOR
	panel.BackgroundTransparency = 0.25
	panel.Parent = gui

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 12)
	panelCorner.Parent = panel

	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = ACCENT_COLOR
	panelStroke.Thickness = 2
	panelStroke.Transparency = 0.2
	panelStroke.Parent = panel

	local countdownLabel = Instance.new("TextLabel")
	countdownLabel.Name = "CountdownLabel"
	countdownLabel.Size = UDim2.fromScale(0.9, 0.75)
	countdownLabel.Position = UDim2.fromScale(0.5, 0.5)
	countdownLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	countdownLabel.BackgroundTransparency = 1
	countdownLabel.TextColor3 = Color3.new(1, 1, 1)
	countdownLabel.TextScaled = true
	countdownLabel.Font = Enum.Font.GothamBold
	countdownLabel.Parent = panel
	label = countdownLabel

	return gui
end

-- Shown once a player is actually in the Match Room (main.client.luau
-- triggers this after the Start Game countdown finishes) and hidden once
-- they're paired (RoundStarted). Text itself only updates from the
-- server's per-second PairingCountdown broadcast below, not a local timer
-- -- the pairing cycle repeats continuously and a client can arrive
-- mid-cycle, so it can't reconstruct "time remaining" on its own.
function PairingCountdownScreen.start()
	active = true
	if not screenGui then
		screenGui = build()
		screenGui.Parent = player:WaitForChild("PlayerGui")
	end
	screenGui.Enabled = true
end

function PairingCountdownScreen.stop()
	active = false
	if screenGui then
		screenGui.Enabled = false
	end
end

Remotes.PairingCountdown.OnClientEvent:Connect(function(secondsRemaining: number)
	if active and label then
		label.Text = "Pairing locks in: " .. secondsRemaining .. "s"
	end
end)

return PairingCountdownScreen
