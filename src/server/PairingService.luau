local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RoundService = require(script.Parent.RoundService)

local PairingService = {}

-- Reserves a private server and teleports player1 into it. Once inside, the
-- client prompts a native game invite (SocialService:PromptGameInvite);
-- Roblox scopes that invite to the inviter's current server instance, so an
-- accepting friend is teleported into the same private server automatically.
function PairingService.createPrivateServer(player1: Player)
	local ok, accessCode = pcall(function()
		return TeleportService:ReserveServer(game.PlaceId)
	end)

	if not ok then
		warn("PairingService: failed to reserve private server -", accessCode)
		return
	end

	local success, err = pcall(function()
		TeleportService:TeleportToPrivateServer(game.PlaceId, accessCode, { player1 })
	end)

	if not success then
		warn("PairingService: failed to teleport to private server -", err)
	end
end

Remotes.RequestPairing.OnServerEvent:Connect(function(player: Player)
	PairingService.createPrivateServer(player)
end)

-- Inside a reserved private server: once a second player joins the
-- inviter, start the Trust round.
if game.PrivateServerId ~= "" then
	Players.PlayerAdded:Connect(function()
		local players = Players:GetPlayers()
		if #players == 2 then
			RoundService.startRound(players[1], players[2])
		end
	end)
end

return PairingService
