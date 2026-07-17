local Config = {
	PAR_TIME = 45,
	MAX_PLAYERS = 4,
	MISTAKE_PENALTY = 10,
	TIME_OVER_PENALTY = 2,

	-- Lobby: "Start Game" countdown before spawning everyone into the Match Room
	GAME_START_COUNTDOWN = 5,

	-- Phase 1: pairing round
	PAIRING_PAD_TAG = "PairingPad",
	PAIRING_TIMER_DURATION = 20, -- seconds; whoever's on a pad when this expires gets paired

	-- Phase 2: Blind Parkour (formerly "Trust round")
	ROUND_TIMEOUT = 120,
	ROLE_BLIND = "Blind",
	ROLE_GUIDE = "Guide",

	-- CollectionService tags for Blind Parkour level geometry
	OBSTACLE_TAG = "TrustObstacle",
	GOAL_TAG = "TrustGoal",

	-- CollectionService tag for the Boulder Cannon hazard's despawn zone
	BOULDER_DESPAWN_TAG = "BoulderDespawn",
}

return Config
