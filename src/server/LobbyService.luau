local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RoundService = require(script.Parent.RoundService)

local LobbyService = {}

local WAIT_TIMEOUT = 10
local SPAWN_SCATTER_RADIUS = 15 -- studs around Match Room's center players are scattered into

local matchRoom = Workspace:WaitForChild("Match Room", WAIT_TIMEOUT)
if not matchRoom then
	warn('LobbyService: Workspace."Match Room" not found within ' .. WAIT_TIMEOUT .. "s — Start Game disabled")
	return LobbyService
end

-- Any player pressing "Start Game" starts one shared countdown for
-- whoever's currently in the lobby -- this flag just stops a second click
-- (from anyone) from starting an overlapping countdown.
local countdownInProgress = false

local function teleportToMatchRoom(player: Player)
	local character = player.Character or player.CharacterAdded:Wait()
	local center = (matchRoom :: PVInstance):GetPivot().Position

	-- No dedicated spawn markers in the Match Room yet (unlike TrustSpawn/
	-- RockSpawn elsewhere) -- scatter around the room's own pivot so 10+
	-- arriving players don't all land in the exact same spot.
	local angle = math.random() * math.pi * 2
	local radius = math.random() * SPAWN_SCATTER_RADIUS
	local offset = Vector3.new(math.cos(angle) * radius, 5, math.sin(angle) * radius)

	character:PivotTo(CFrame.new(center + offset))
end

local function startGame()
	if countdownInProgress then
		return
	end
	countdownInProgress = true

	Remotes.GameStarting:FireAllClients(Config.GAME_START_COUNTDOWN)
	task.wait(Config.GAME_START_COUNTDOWN)

	for _, player in Players:GetPlayers() do
		-- Don't yank a player already mid-round on the shared course back
		-- into the Match Room if someone else starts another wave.
		if not RoundService.isPlayerInRound(player) then
			teleportToMatchRoom(player)
		end
	end

	countdownInProgress = false
end

Remotes.RequestGameStart.OnServerEvent:Connect(function()
	startGame()
end)

return LobbyService
