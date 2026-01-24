-- ModuleScript in ServerScriptService/Modules/MapManager
local ServerStorage = game:GetService("ServerStorage")

local MapManager = {}

local mapsFolder = ServerStorage:WaitForChild("Maps")
local availableMaps = {}
local currentMapA = nil
local currentMapB = nil
local preloadedMapA = nil
local preloadedMapB = nil
local mapASpawnPos = nil
local mapBSpawnPos = nil

-- Config
local MAP_SPACING = 500
local MAP_HEIGHT = 100

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

-- Calculate map position
local function getMapPosition(index)
	local x = (index - 1) * MAP_SPACING
	return Vector3.new(x, MAP_HEIGHT, 0)
end

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

-- Place preloaded maps in workspace
function MapManager.Place()
	if not preloadedMapA or not preloadedMapB then
		warn("[MapManager] No preloaded maps! Preloading now...")
		MapManager.Preload()
	end

	-- Position maps
	local posA = getMapPosition(1)
	local posB = getMapPosition(2)

	if preloadedMapA:IsA("Model") then
		preloadedMapA:PivotTo(CFrame.new(posA))
	else
		-- For folder-based maps, move all parts
		for _, part in preloadedMapA:GetDescendants() do
			if part:IsA("BasePart") then
				part.Position = part.Position + posA
			end
		end
	end

	if preloadedMapB:IsA("Model") then
		preloadedMapB:PivotTo(CFrame.new(posB))
	else
		for _, part in preloadedMapB:GetDescendants() do
			if part:IsA("BasePart") then
				part.Position = part.Position + posB
			end
		end
	end

	-- Parent to workspace
	preloadedMapA.Parent = workspace
	preloadedMapB.Parent = workspace

	-- Store references
	currentMapA = preloadedMapA
	currentMapB = preloadedMapB

	-- Find spawn positions
	mapASpawnPos = findSpawnInMap(currentMapA)
	mapBSpawnPos = findSpawnInMap(currentMapB)

	-- Clear preloaded references
	preloadedMapA = nil
	preloadedMapB = nil

	print("[MapManager] Placed maps - SpawnA:", mapASpawnPos, "SpawnB:", mapBSpawnPos)
end

-- Get spawn positions
function MapManager.GetSpawnPositions()
	return mapASpawnPos, mapBSpawnPos
end

-- Get current maps
function MapManager.GetMaps()
	return currentMapA, currentMapB
end

-- Cleanup current maps
function MapManager.Cleanup()
	if currentMapA and currentMapA.Parent then
		currentMapA:Destroy()
	end
	if currentMapB and currentMapB.Parent then
		currentMapB:Destroy()
	end

	currentMapA = nil
	currentMapB = nil
	mapASpawnPos = nil
	mapBSpawnPos = nil

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

print("[MapManager] Loaded")
return MapManager