local Players = game:GetService("Players")

local player = Players.LocalPlayer

local ResultsScreen = {}

local screenGui: ScreenGui? = nil
local scoreLabel: TextLabel? = nil
local breakdownLabel: TextLabel? = nil

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ResultsScreen"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 200
	gui.Enabled = false

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(0.4, 0.35)
	frame.Position = UDim2.fromScale(0.3, 0.32)
	frame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
	frame.BackgroundTransparency = 0.1
	frame.Parent = gui

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.fromScale(1, 0.2)
	title.BackgroundTransparency = 1
	title.Text = "Sync Score"
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = frame

	local score = Instance.new("TextLabel")
	score.Name = "Score"
	score.Size = UDim2.fromScale(1, 0.35)
	score.Position = UDim2.fromScale(0, 0.2)
	score.BackgroundTransparency = 1
	score.TextColor3 = Color3.new(1, 1, 1)
	score.TextScaled = true
	score.Font = Enum.Font.GothamBold
	score.Parent = frame

	local breakdown = Instance.new("TextLabel")
	breakdown.Name = "Breakdown"
	breakdown.Size = UDim2.fromScale(0.9, 0.4)
	breakdown.Position = UDim2.fromScale(0.05, 0.55)
	breakdown.BackgroundTransparency = 1
	breakdown.TextColor3 = Color3.new(0.85, 0.85, 0.85)
	breakdown.TextScaled = true
	breakdown.TextWrapped = true
	breakdown.TextXAlignment = Enum.TextXAlignment.Left
	breakdown.Font = Enum.Font.Gotham
	breakdown.Parent = frame

	return gui, score, breakdown
end

function ResultsScreen.show(data)
	if not screenGui then
		screenGui, scoreLabel, breakdownLabel = build()
		screenGui.Parent = player:WaitForChild("PlayerGui")
	end

	scoreLabel.Text = string.format("%d / 100", math.round(data.score))
	breakdownLabel.Text = string.format(
		"Mistakes: %d (-%d)\nTime: %.1fs (-%d)",
		data.mistakes,
		data.mistakePenalty,
		data.timeElapsed,
		math.round(data.timePenalty)
	)

	screenGui.Enabled = true
end

function ResultsScreen.hide()
	if screenGui then
		screenGui.Enabled = false
	end
end

return ResultsScreen
