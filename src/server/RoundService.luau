local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ScoreService = require(script.Parent.ScoreService)

local RoundService = {}

-- Multiple pairs now run Blind Parkour on the same shared course at once
-- (no private servers, no duplicated course copies), so round state is
-- keyed per player instead of a single module-level round.
local playerToRound: { [Player]: any } = {}

local WAIT_TIMEOUT = 10
local SPAWN_SCATTER_RADIUS = 3 -- studs around BlindObbySpawnCenter each spawned player is scattered into

local blindObby = Workspace:WaitForChild("BlindObby", WAIT_TIMEOUT)
local spawnCenter = blindObby and blindObby:WaitForChild("BlindObbySpawnCenter", WAIT_TIMEOUT)
if not spawnCenter then
	warn("RoundService: Workspace.BlindObby.BlindObbySpawnCenter not found within " .. WAIT_TIMEOUT .. "s — Blind Parkour spawning disabled")
end

-- Every player just scatters around one shared center point rather than
-- claiming a dedicated marker per pair — since every pair already shares
-- one course simultaneously, there's no exclusivity to track, and this
-- removes the earlier capacity concern (needing 2 tagged spawns per
-- concurrent pair).
local function teleportToSpawn(player: Player)
	local character = player.Character or player.CharacterAdded:Wait()
	local center = (spawnCenter :: PVInstance):GetPivot().Position
	local angle = math.random() * math.pi * 2
	local radius = math.random() * SPAWN_SCATTER_RADIUS
	local offset = Vector3.new(math.cos(angle) * radius, 3, math.sin(angle) * radius)
	character:PivotTo(CFrame.new(center + offset))
end

-- Exposed so PairingService can exclude players already mid-round from
-- being re-paired off a pairing pad.
function RoundService.isPlayerInRound(player: Player): boolean
	return playerToRound[player] ~= nil
end

local function endRound(round)
	if round.ended then
		return
	end
	round.ended = true

	for _, connection in round.connections do
		connection:Disconnect()
	end
	playerToRound[round.player1] = nil
	playerToRound[round.player2] = nil

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
end

function RoundService.startRound(player1: Player, player2: Player)
	if RoundService.isPlayerInRound(player1) or RoundService.isPlayerInRound(player2) then
		warn("RoundService: startRound called for a player already in a round")
		return
	end

	if not spawnCenter then
		warn("RoundService: cannot start round — Workspace.BlindObby.BlindObbySpawnCenter is missing")
		return
	end

	local blindIsPlayer1 = math.random() < 0.5
	local blindPlayer = blindIsPlayer1 and player1 or player2
	local guidePlayer = blindIsPlayer1 and player2 or player1

	teleportToSpawn(player1)
	teleportToSpawn(player2)

	local round = {
		player1 = player1,
		player2 = player2,
		blindPlayer = blindPlayer,
		guidePlayer = guidePlayer,
		mistakes = 0,
		startClock = os.clock(),
		ended = false,
		connections = {},
	}

	playerToRound[player1] = round
	playerToRound[player2] = round

	Remotes.RoundStarted:FireClient(blindPlayer, { role = Config.ROLE_BLIND })
	Remotes.RoundStarted:FireClient(guidePlayer, { role = Config.ROLE_GUIDE })

	local function isThisRoundsBlindPart(hit: BasePart): boolean
		local character = blindPlayer.Character
		return character ~= nil and hit:IsDescendantOf(character)
	end

	-- Relays this round's blind player's camera to this round's guide only
	-- — obstacles/goals below are shared geometry touched by every
	-- concurrent pair, so every round keeps its own connection filtered to
	-- its own blindPlayer rather than there being one global listener.
	local cameraSyncConnection = Remotes.CameraSync.OnServerEvent:Connect(function(player, cframe)
		if player == blindPlayer and typeof(cframe) == "CFrame" then
			Remotes.CameraSync:FireClient(guidePlayer, cframe)
		end
	end)
	table.insert(round.connections, cameraSyncConnection)

	for _, obstacle in CollectionService:GetTagged(Config.OBSTACLE_TAG) do
		local connection = (obstacle :: BasePart).Touched:Connect(function(hit)
			if isThisRoundsBlindPart(hit) then
				round.mistakes += 1
			end
		end)
		table.insert(round.connections, connection)
	end

	for _, goal in CollectionService:GetTagged(Config.GOAL_TAG) do
		local connection = (goal :: BasePart).Touched:Connect(function(hit)
			if isThisRoundsBlindPart(hit) then
				endRound(round)
			end
		end)
		table.insert(round.connections, connection)
	end

	task.delay(Config.ROUND_TIMEOUT, function()
		endRound(round)
	end)
end

-- Multiple concurrent rounds mean a stale round (the other player waiting
-- forever, their Touched/CameraSync connections never cleaned up) is much
-- more likely if someone disconnects mid-round than it was with a single
-- round per server.
Players.PlayerRemoving:Connect(function(player)
	local round = playerToRound[player]
	if round then
		endRound(round)
	end
end)

return RoundService
