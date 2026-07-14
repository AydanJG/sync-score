local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local CourseBuilder = {}

-- Modern neon minigame palette
local COLOR_DARK_BASE = Color3.fromRGB(30, 30, 36)
local COLOR_NEON_CYAN = Color3.fromRGB(60, 220, 255)
local COLOR_NEON_GOLD = Color3.fromRGB(255, 200, 60)

-- Level-geometry dimensions (not shared gameplay constants, so they stay
-- local to this file rather than in Config.luau)
local LOBBY_SIZE = 40
local LOBBY_TRIM_THICKNESS = 1
local CORRIDOR_WIDTH = 12
local WALL_HEIGHT = 8
local WALL_THICKNESS = 1
local SEGMENT_SPACING = 10
local NUM_SEGMENTS = 8
local GAP_WIDTH = 4

local function createPart(props: { [string]: any }): BasePart
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	return part
end

local function buildLobby(parent: Instance): Vector3
	createPart({
		Name = "LobbyFloor",
		Size = Vector3.new(LOBBY_SIZE, 2, LOBBY_SIZE),
		Position = Vector3.new(0, -1, 0),
		Material = Enum.Material.Slate,
		Color = COLOR_DARK_BASE,
		Parent = parent,
	})

	local halfSize = LOBBY_SIZE / 2
	local trims = {
		{ Vector3.new(LOBBY_SIZE, 0.4, LOBBY_TRIM_THICKNESS), Vector3.new(0, 0.2, -halfSize) },
		{ Vector3.new(LOBBY_SIZE, 0.4, LOBBY_TRIM_THICKNESS), Vector3.new(0, 0.2, halfSize) },
		{ Vector3.new(LOBBY_TRIM_THICKNESS, 0.4, LOBBY_SIZE), Vector3.new(-halfSize, 0.2, 0) },
		{ Vector3.new(LOBBY_TRIM_THICKNESS, 0.4, LOBBY_SIZE), Vector3.new(halfSize, 0.2, 0) },
	}
	for i, trim in trims do
		createPart({
			Name = "LobbyTrim" .. i,
			Size = trim[1],
			Position = trim[2],
			Material = Enum.Material.Neon,
			Color = COLOR_NEON_CYAN,
			CanCollide = false,
			Parent = parent,
		})
	end

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "Spawn"
	spawnLocation.Size = Vector3.new(6, 1, 6)
	spawnLocation.Position = Vector3.new(0, 0.5, -halfSize / 2)
	spawnLocation.Anchored = true
	spawnLocation.Material = Enum.Material.Slate
	spawnLocation.Color = COLOR_DARK_BASE
	spawnLocation.Enabled = true
	spawnLocation.Neutral = true
	spawnLocation.Duration = 0
	spawnLocation.Parent = parent

	return Vector3.new(0, 0, halfSize)
end

-- Builds a slalom corridor: alternating baffle walls force an S-path, and
-- a clear goal chamber sits past the last baffle. Returns the baffle
-- area length and goal chamber length so placeGoal/placeSpawnMarkers can
-- position themselves relative to the generated geometry.
local function buildCorridor(parent: Instance, startPos: Vector3): (number, number)
	local baffleAreaLength = NUM_SEGMENTS * SEGMENT_SPACING
	local goalChamberLength = SEGMENT_SPACING
	local totalLength = baffleAreaLength + goalChamberLength
	local halfWidth = CORRIDOR_WIDTH / 2
	local startZ = startPos.Z

	createPart({
		Name = "CorridorFloor",
		Size = Vector3.new(CORRIDOR_WIDTH, 1, totalLength),
		Position = Vector3.new(0, -0.5, startZ + totalLength / 2),
		Material = Enum.Material.Slate,
		Color = COLOR_DARK_BASE,
		Parent = parent,
	})

	for _, side in { -1, 1 } do
		local wall = createPart({
			Name = "CorridorWall" .. (side == -1 and "Left" or "Right"),
			Size = Vector3.new(WALL_THICKNESS, WALL_HEIGHT, totalLength),
			Position = Vector3.new(side * halfWidth, WALL_HEIGHT / 2, startZ + totalLength / 2),
			Material = Enum.Material.Concrete,
			Color = COLOR_DARK_BASE,
			Parent = parent,
		})
		CollectionService:AddTag(wall, Config.OBSTACLE_TAG)
	end

	local baffleLength = CORRIDOR_WIDTH - GAP_WIDTH
	for i = 1, NUM_SEGMENTS do
		local fromLeft = (i % 2 == 0)
		local edgeX = fromLeft and -halfWidth or halfWidth
		local centerX = fromLeft and (edgeX + baffleLength / 2) or (edgeX - baffleLength / 2)
		local z = startZ + i * SEGMENT_SPACING

		local baffle = createPart({
			Name = "Baffle" .. i,
			Size = Vector3.new(baffleLength, WALL_HEIGHT, WALL_THICKNESS),
			Position = Vector3.new(centerX, WALL_HEIGHT / 2, z),
			Material = Enum.Material.Concrete,
			Color = COLOR_DARK_BASE,
			Parent = parent,
		})
		CollectionService:AddTag(baffle, Config.OBSTACLE_TAG)

		local trimX = fromLeft and (centerX + baffleLength / 2) or (centerX - baffleLength / 2)
		createPart({
			Name = "BaffleTrim" .. i,
			Size = Vector3.new(0.2, WALL_HEIGHT, WALL_THICKNESS + 0.2),
			Position = Vector3.new(trimX, WALL_HEIGHT / 2, z),
			Material = Enum.Material.Neon,
			Color = COLOR_NEON_CYAN,
			CanCollide = false,
			Parent = parent,
		})
	end

	return baffleAreaLength, goalChamberLength
end

local function placeSpawnMarkers(parent: Instance, startPos: Vector3)
	for i = 1, 2 do
		local marker = createPart({
			Name = "TrustSpawn" .. i,
			Size = Vector3.new(3, 0.4, 3),
			Position = Vector3.new((i == 1) and -2 or 2, 0.2, startPos.Z + 2),
			Material = Enum.Material.Neon,
			Color = COLOR_NEON_CYAN,
			CanCollide = false,
			Parent = parent,
		})
		CollectionService:AddTag(marker, Config.SPAWN_TAG)
	end
end

local function placeGoal(parent: Instance, startPos: Vector3, baffleAreaLength: number, goalChamberLength: number)
	local goalZ = startPos.Z + baffleAreaLength + goalChamberLength / 2

	local pad = createPart({
		Name = "TrustGoal",
		Size = Vector3.new(CORRIDOR_WIDTH - 2, 0.4, 4),
		Position = Vector3.new(0, 0.2, goalZ),
		Material = Enum.Material.Neon,
		Color = COLOR_NEON_GOLD,
		Parent = parent,
	})
	CollectionService:AddTag(pad, Config.GOAL_TAG)

	local light = Instance.new("PointLight")
	light.Color = COLOR_NEON_GOLD
	light.Range = 20
	light.Brightness = 3
	light.Parent = pad

	-- Orientation (0,0,90) lays the cylinder flat, mapping its local X
	-- (the cylinder's axis) onto world up, so spinning around local X
	-- each frame reads as a halo rotating flat above the goal.
	local ring = createPart({
		Name = "GoalRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 6, 6),
		Position = Vector3.new(0, 4, goalZ),
		Orientation = Vector3.new(0, 0, 90),
		Material = Enum.Material.Neon,
		Color = COLOR_NEON_GOLD,
		CanCollide = false,
		Transparency = 0.3,
		Parent = parent,
	})

	RunService.Heartbeat:Connect(function(dt: number)
		ring.CFrame = ring.CFrame * CFrame.Angles(dt, 0, 0)
	end)
end

function CourseBuilder.build()
	if Workspace:FindFirstChild("GeneratedMap") then
		return
	end

	local map = Instance.new("Folder")
	map.Name = "GeneratedMap"

	local corridorStart = buildLobby(map)
	local baffleAreaLength, goalChamberLength = buildCorridor(map, corridorStart)
	placeSpawnMarkers(map, corridorStart)
	placeGoal(map, corridorStart, baffleAreaLength, goalChamberLength)

	map.Parent = Workspace
end

return CourseBuilder
