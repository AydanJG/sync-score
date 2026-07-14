local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local ScoreService = {}

function ScoreService.calculateScore(mistakes: number, timeElapsed: number): number
	local score = 100
		- (mistakes * Config.MISTAKE_PENALTY)
		- (math.max(0, timeElapsed - Config.PAR_TIME) * Config.TIME_OVER_PENALTY)

	return math.clamp(score, 0, 100)
end

return ScoreService
