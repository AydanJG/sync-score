local Players = game:GetService("Players")

local player = Players.LocalPlayer

local BlindOverlay = {}

local screenGui: ScreenGui? = nil

local function build(): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "BlindOverlay"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.new(0, 0, 0)
	frame.BackgroundTransparency = 0.05
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 0.1)
	label.Position = UDim2.fromScale(0, 0.45)
	label.BackgroundTransparency = 1
	label.Text = "Trust your guide..."
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = frame

	return gui
end

function BlindOverlay.show()
	if not screenGui then
		screenGui = build()
		screenGui.Parent = player:WaitForChild("PlayerGui")
	end
	screenGui.Enabled = true
end

function BlindOverlay.hide()
	if screenGui then
		screenGui.Enabled = false
	end
end

return BlindOverlay
