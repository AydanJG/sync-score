local Config = {
	PAR_TIME = 45,
	MAX_PLAYERS = 4,
	MISTAKE_PENALTY = 10,
	TIME_OVER_PENALTY = 2,

	-- Trust round
	ROUND_TIMEOUT = 120,
	ROLE_BLIND = "Blind",
	ROLE_GUIDE = "Guide",

	-- CollectionService tags for Trust round level geometry
	OBSTACLE_TAG = "TrustObstacle",
	GOAL_TAG = "TrustGoal",
	SPAWN_TAG = "TrustSpawn",

	-- CollectionService tag for the Boulder Cannon hazard's despawn zone
	BOULDER_DESPAWN_TAG = "BoulderDespawn",
}

return Config
