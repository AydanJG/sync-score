local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ScoreService = require(script.Parent.ScoreService)

local RoundService = {}

-- Only one Trust round runs at a time per server (each private server hosts
-- exactly one pair), so module-level state is sufficient.
local currentRound = nil

local function getSpawnParts()
	return CollectionService:GetTagged(Config.SPAWN_TAG)
end

local function teleportToSpawn(player: Player, spawnPart: BasePart)
	local character = player.Character or player.CharacterAdded:Wait()
	character:PivotTo(spawnPart.CFrame + Vector3.new(0, 3, 0))
end

local function isBlindPlayerPart(hit: BasePart): boolean
	local round = currentRound
	local character = round and round.blindPlayer.Character
	return character ~= nil and hit:IsDescendantOf(character)
end

local function endRound(roundToken: number)
	local round = currentRound
	if not round or round.token ~= roundToken or round.ended then
		return
	end
	round.ended = true

	for _, connection in round.connections do
		connection:Disconnect()
	end

	local timeElapsed = os.clock() - round.startClock
	local score = ScoreService.calculateScore(round.mistakes, timeElapsed)
	local mistakePenalty = round.mistakes * Config.MISTAKE_PENALTY
	local timePenalty = math.max(0, timeElapsed - Config.PAR_TIME) * Config.TIME_OVER_PENALTY

	local payload = {
		score = score,
		mistakes = round.mistakes,
		timeElapsed = timeElapsed,
		mistakePenalty = mistakePenalty,
		timePenalty = timePenalty,
	}

	Remotes.RoundEnded:FireClient(round.player1, payload)
	Remotes.RoundEnded:FireClient(round.player2, payload)

	currentRound = nil
end

function RoundService.startRound(player1: Player, player2: Player)
	if currentRound then
		return
	end

	local spawns = getSpawnParts()
	if #spawns < 2 then
		warn("RoundService: need at least 2 parts tagged " .. Config.SPAWN_TAG)
		return
	end

	local blindIsPlayer1 = math.random() < 0.5
	local blindPlayer = blindIsPlayer1 and player1 or player2
	local guidePlayer = blindIsPlayer1 and player2 or player1

	teleportToSpawn(player1, spawns[1])
	teleportToSpawn(player2, spawns[2])

	local roundToken = os.clock()
	currentRound = {
		token = roundToken,
		player1 = player1,
		player2 = player2,
		blindPlayer = blindPlayer,
		mistakes = 0,
		startClock = os.clock(),
		ended = false,
		connections = {},
	}

	Remotes.RoundStarted:FireClient(blindPlayer, { role = Config.ROLE_BLIND })
	Remotes.RoundStarted:FireClient(guidePlayer, { role = Config.ROLE_GUIDE })

	for _, obstacle in CollectionService:GetTagged(Config.OBSTACLE_TAG) do
		local connection = (obstacle :: BasePart).Touched:Connect(function(hit)
			if isBlindPlayerPart(hit) then
				currentRound.mistakes += 1
			end
		end)
		table.insert(currentRound.connections, connection)
	end

	for _, goal in CollectionService:GetTagged(Config.GOAL_TAG) do
		local connection = (goal :: BasePart).Touched:Connect(function(hit)
			if isBlindPlayerPart(hit) then
				endRound(roundToken)
			end
		end)
		table.insert(currentRound.connections, connection)
	end

	task.delay(Config.ROUND_TIMEOUT, function()
		endRound(roundToken)
	end)
end

-- Studio-only dev bypass: TeleportService (and therefore PairingService)
-- doesn't function in Studio's local "Test -> Clients and Servers", so this
-- lets 2 local test clients skip real pairing and jump straight into a
-- round together. Never runs in a published place.
if RunService:IsStudio() then
	Players.PlayerAdded:Connect(function()
		if currentRound then
			return
		end

		task.wait(2) -- give both test clients a moment to join

		local players = Players:GetPlayers()
		if #players >= 2 and not currentRound then
			RoundService.startRound(players[1], players[2])
		end
	end)
end

return RoundService
