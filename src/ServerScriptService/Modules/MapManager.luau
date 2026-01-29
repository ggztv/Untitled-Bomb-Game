-- ModuleScript in ServerScriptService/Modules/MapManager
local ServerStorage = game:GetService("ServerStorage")

local MapManager = {}

local mapsFolder = ServerStorage:WaitForChild("Maps")
local availableMaps = {}

-- Config
local MAP_OFFSET = 750 -- Distance from origin
local MAP_SPACING = 750 -- Distance between maps
local MAP_HEIGHT = 100
local MAX_CONCURRENT_MATCHES = 6

-- Grid state: tracks active matches by slot
-- Grid layout (X = column for MapA/MapB, Z = row for match):
-- Match 0: MapA at (750, 100, 750), MapB at (1500, 100, 750)
-- Match 1: MapA at (750, 100, 1500), MapB at (1500, 100, 1500)
-- etc.
local activeMatches = {} -- matchId -> {mapA, mapB, spawnA, spawnB, gridRow}
local usedGridRows = {} -- gridRow -> matchId

-- Legacy single-match support (for backwards compatibility)
local currentMapA = nil
local currentMapB = nil
local preloadedMapA = nil
local preloadedMapB = nil
local mapASpawnPos = nil
local mapBSpawnPos = nil
local currentMatchId = nil

-- Load available maps
for _, map in mapsFolder:GetChildren() do
	if map:IsA("Model") or map:IsA("Folder") then
		table.insert(availableMaps, map)
		print("[MapManager] Found map:", map.Name)
	end
end

-- Get random map (avoid duplicates)
local function getRandomMap(exclude)
	local choices = {}
	for _, map in availableMaps do
		if map ~= exclude then
			table.insert(choices, map)
		end
	end

	if #choices == 0 then
		return availableMaps[math.random(1, #availableMaps)]
	end

	return choices[math.random(1, #choices)]
end

-- Find spawn location in map
local function findSpawnInMap(map)
	-- Look for SpawnLocation
	local spawn = map:FindFirstChild("SpawnLocation", true)
	if spawn then
		return spawn.Position
	end

	-- Look for Spawn part
	spawn = map:FindFirstChild("Spawn", true)
	if spawn and spawn:IsA("BasePart") then
		return spawn.Position
	end

	-- Look for any part named Spawn
	for _, child in map:GetDescendants() do
		if child:IsA("BasePart") and child.Name:lower():find("spawn") then
			return child.Position
		end
	end

	-- Fallback to center of map
	if map:IsA("Model") then
		local cf, size = map:GetBoundingBox()
		return cf.Position + Vector3.new(0, 5, 0)
	end

	-- Last resort
	local firstPart = map:FindFirstChildWhichIsA("BasePart", true)
	if firstPart then
		return firstPart.Position + Vector3.new(0, 5, 0)
	end

	return Vector3.new(0, MAP_HEIGHT, 0)
end

-- Calculate grid position for a map
-- gridRow: which match row (0-5)
-- column: 0 for MapA, 1 for MapB
local function getGridPosition(gridRow, column)
	local x = MAP_OFFSET + (column * MAP_SPACING)
	local z = MAP_OFFSET + (gridRow * MAP_SPACING)
	return Vector3.new(x, MAP_HEIGHT, z)
end

-- Find next available grid row
local function findAvailableGridRow()
	for row = 0, MAX_CONCURRENT_MATCHES - 1 do
		if not usedGridRows[row] then
			return row
		end
	end
	return nil -- No available slots
end

-- Position a map at given position
local function positionMap(map, position)
	if map:IsA("Model") then
		map:PivotTo(CFrame.new(position))
	else
		-- For folder-based maps, move all parts
		local firstPart = map:FindFirstChildWhichIsA("BasePart", true)
		local offset = position
		if firstPart then
			offset = position - firstPart.Position
		end
		for _, part in map:GetDescendants() do
			if part:IsA("BasePart") then
				part.Position = part.Position + offset
			end
		end
	end
end

-- Generate unique match ID
local matchIdCounter = 0
local function generateMatchId()
	matchIdCounter += 1
	return "match_" .. matchIdCounter
end

--[[ ==================== MULTI-MATCH API ==================== ]]--

-- Create a new match with maps placed on the grid
-- Returns matchId or nil if no slots available
function MapManager.CreateMatch()
	local gridRow = findAvailableGridRow()
	if not gridRow then
		warn("[MapManager] No available grid slots for new match!")
		return nil
	end

	-- Pick two different maps
	local mapATemplate = getRandomMap(nil)
	local mapBTemplate = getRandomMap(mapATemplate)

	-- Clone maps
	local mapA = mapATemplate:Clone()
	local mapB = mapBTemplate:Clone()

	-- Calculate positions
	local posA = getGridPosition(gridRow, 0)
	local posB = getGridPosition(gridRow, 1)

	-- Position maps
	positionMap(mapA, posA)
	positionMap(mapB, posB)

	-- Generate match ID first so we can tag maps
	local matchId = generateMatchId()

	-- Tag maps with match ID for visibility filtering
	mapA:SetAttribute("MatchId", matchId)
	mapB:SetAttribute("MatchId", matchId)

	-- Parent to workspace
	mapA.Parent = workspace
	mapB.Parent = workspace

	-- Find spawn positions
	local spawnA = findSpawnInMap(mapA)
	local spawnB = findSpawnInMap(mapB)
	activeMatches[matchId] = {
		mapA = mapA,
		mapB = mapB,
		spawnA = spawnA,
		spawnB = spawnB,
		gridRow = gridRow
	}
	usedGridRows[gridRow] = matchId

	print("[MapManager] Created match", matchId, "at grid row", gridRow)
	print("[MapManager] MapA:", mapA.Name, "at", posA, "| MapB:", mapB.Name, "at", posB)

	return matchId
end

-- Get maps for a specific match
function MapManager.GetMatchMaps(matchId)
	local match = activeMatches[matchId]
	if not match then return nil, nil end
	return match.mapA, match.mapB
end

-- Get spawn positions for a specific match
function MapManager.GetMatchSpawnPositions(matchId)
	local match = activeMatches[matchId]
	if not match then return nil, nil end
	return match.spawnA, match.spawnB
end

-- Cleanup a specific match
function MapManager.CleanupMatch(matchId)
	local match = activeMatches[matchId]
	if not match then return end

	if match.mapA and match.mapA.Parent then
		match.mapA:Destroy()
	end
	if match.mapB and match.mapB.Parent then
		match.mapB:Destroy()
	end

	usedGridRows[match.gridRow] = nil
	activeMatches[matchId] = nil

	print("[MapManager] Cleaned up match", matchId)
end

-- Get active match count
function MapManager.GetActiveMatchCount()
	local count = 0
	for _ in activeMatches do
		count += 1
	end
	return count
end

-- Check if more matches can be created
function MapManager.CanCreateMatch()
	return findAvailableGridRow() ~= nil
end

--[[ ==================== LEGACY SINGLE-MATCH API ==================== ]]--
-- (Backwards compatible with existing RoundScript)

-- Preload maps (clone but don't parent yet)
function MapManager.Preload()
	-- Clean up old preloaded maps
	MapManager.CleanupPreloaded()

	-- Pick two different maps
	local mapA = getRandomMap(nil)
	local mapB = getRandomMap(mapA)

	-- Clone maps
	preloadedMapA = mapA:Clone()
	preloadedMapB = mapB:Clone()

	print("[MapManager] Preloaded maps:", preloadedMapA.Name, preloadedMapB.Name)
end

-- Place preloaded maps in workspace (uses grid system)
function MapManager.Place()
	if not preloadedMapA or not preloadedMapB then
		warn("[MapManager] No preloaded maps! Preloading now...")
		MapManager.Preload()
	end

	-- Find available grid row
	local gridRow = findAvailableGridRow()
	if not gridRow then
		warn("[MapManager] No available grid slots!")
		gridRow = 0 -- Fallback to row 0
	end

	-- Calculate positions using grid
	local posA = getGridPosition(gridRow, 0)
	local posB = getGridPosition(gridRow, 1)

	-- Generate match ID first so we can tag maps
	currentMatchId = generateMatchId()

	-- Tag maps with match ID for visibility filtering
	preloadedMapA:SetAttribute("MatchId", currentMatchId)
	preloadedMapB:SetAttribute("MatchId", currentMatchId)

	-- Position maps
	positionMap(preloadedMapA, posA)
	positionMap(preloadedMapB, posB)

	-- Parent to workspace
	preloadedMapA.Parent = workspace
	preloadedMapB.Parent = workspace

	-- Store references
	currentMapA = preloadedMapA
	currentMapB = preloadedMapB

	-- Find spawn positions
	mapASpawnPos = findSpawnInMap(currentMapA)
	mapBSpawnPos = findSpawnInMap(currentMapB)
	activeMatches[currentMatchId] = {
		mapA = currentMapA,
		mapB = currentMapB,
		spawnA = mapASpawnPos,
		spawnB = mapBSpawnPos,
		gridRow = gridRow
	}
	usedGridRows[gridRow] = currentMatchId

	-- Clear preloaded references
	preloadedMapA = nil
	preloadedMapB = nil

	print("[MapManager] Placed maps at grid row", gridRow)
	print("[MapManager] SpawnA:", mapASpawnPos, "SpawnB:", mapBSpawnPos)
end

-- Get spawn positions (legacy)
function MapManager.GetSpawnPositions()
	return mapASpawnPos, mapBSpawnPos
end

-- Get current maps (legacy)
function MapManager.GetMaps()
	return currentMapA, currentMapB
end

-- Get current match ID
function MapManager.GetCurrentMatchId()
	return currentMatchId
end

-- Cleanup current maps (legacy)
function MapManager.Cleanup()
	if currentMatchId then
		MapManager.CleanupMatch(currentMatchId)
	end

	currentMapA = nil
	currentMapB = nil
	mapASpawnPos = nil
	mapBSpawnPos = nil
	currentMatchId = nil

	print("[MapManager] Cleaned up maps")
end

-- Cleanup preloaded maps
function MapManager.CleanupPreloaded()
	if preloadedMapA then
		preloadedMapA:Destroy()
		preloadedMapA = nil
	end
	if preloadedMapB then
		preloadedMapB:Destroy()
		preloadedMapB = nil
	end
end

-- Get map count
function MapManager.GetMapCount()
	return #availableMaps
end

-- Get map names
function MapManager.GetMapNames()
	local names = {}
	for _, map in availableMaps do
		table.insert(names, map.Name)
	end
	return names
end

print("[MapManager] Loaded with grid support (offset:", MAP_OFFSET, "spacing:", MAP_SPACING, ")")
return MapManager
