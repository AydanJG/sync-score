local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local LobbyScreen = {}

local screenGui: ScreenGui? = nil

local function promptInvite()
	local ok, canInvite = pcall(function()
		return SocialService:CanSendGameInviteAsync(player)
	end)

	if ok and canInvite then
		SocialService:PromptGameInvite(player)
	else
		warn("LobbyScreen: game invites unavailable for this player/platform")
	end
end

local function onInviteClicked()
	if game.PrivateServerId == "" then
		-- Public server: ask the server to reserve a private server and
		-- teleport us into it.
		Remotes.RequestPairing:FireServer()
	else
		-- Already in our private server: invite a friend to join it.
		promptInvite()
	end
end

function LobbyScreen.show()
	if screenGui then
		screenGui.Enabled = true
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "LobbyScreen"
	gui.ResetOnSpawn = false

	local button = Instance.new("TextButton")
	button.Name = "InviteButton"
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.fromScale(0.5, 0.85)
	button.Size = UDim2.fromOffset(220, 50)
	button.BackgroundColor3 = Color3.fromRGB(60, 120, 255)
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextScaled = true
	button.Font = Enum.Font.GothamBold
	button.Text = "Invite Friend"
	button.Parent = gui

	button.MouseButton1Click:Connect(onInviteClicked)

	gui.Parent = player:WaitForChild("PlayerGui")
	screenGui = gui
end

function LobbyScreen.hide()
	if screenGui then
		screenGui.Enabled = false
	end
end

return LobbyScreen
