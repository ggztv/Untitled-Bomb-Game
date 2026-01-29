-- ModuleScript in ServerScriptService/Modules/SpawnManager
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SpawnManager = {}

local lobbySpawn = nil
local lobbySpawnPosition = nil
local lobbyEnabled = true
local playersInMatch = {}
local playerMapAssignments = {}
local boundaryCheckConnection = nil
local playerLastGoodPositions = {} -- Track last valid position for each player
local playerFullySpawned = {} -- Track if player has been fully spawned at their map

-- Initialize
function SpawnManager.Init(spawn)
	lobbySpawn = spawn
	lobbySpawnPosition = spawn.Position
	print("[SpawnManager] Initialized with lobby spawn")
end

-- Set player in match
function SpawnManager.SetPlayerInMatch(player, inMatch)
	playersInMatch[player] = inMatch or nil
end

-- Check if player is in match
function SpawnManager.IsPlayerInMatch(player)
	return playersInMatch[player] == true
end

-- Assign player to map (for boundary checking)
function SpawnManager.AssignPlayerToMap(player, mapFolder, spawnPosition)
	playerMapAssignments[player] = {
		map = mapFolder,
		spawn = spawnPosition,
		matchId = mapFolder and mapFolder:GetAttribute("MatchId")
	}
end

-- Clear player map assignment
function SpawnManager.ClearPlayerAssignment(player)
	playerMapAssignments[player] = nil
	playerLastGoodPositions[player] = nil
	playerFullySpawned[player] = nil
end

-- Clear all assignments
function SpawnManager.ClearAllAssignments()
	playerMapAssignments = {}
	playersInMatch = {}
	playerLastGoodPositions = {}
	playerFullySpawned = {}
end

-- Get map bounds
local function getMapBounds(mapFolder)
	if not mapFolder then return nil end

	local minX, minY, minZ = math.huge, math.huge, math.huge
	local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge

	for _, part in mapFolder:GetDescendants() do
		if part:IsA("BasePart") then
			local pos = part.Position
			local size = part.Size / 2
			minX = math.min(minX, pos.X - size.X)
			minY = math.min(minY, pos.Y - size.Y)
			minZ = math.min(minZ, pos.Z - size.Z)
			maxX = math.max(maxX, pos.X + size.X)
			maxY = math.max(maxY, pos.Y + size.Y)
			maxZ = math.max(maxZ, pos.Z + size.Z)
		end
	end

	-- Add padding
	local padding = 50
	return {
		min = Vector3.new(minX - padding, minY - padding, minZ - padding),
		max = Vector3.new(maxX + padding, maxY + padding, maxZ + padding)
	}
end

-- Check if position is within bounds
local function isWithinBounds(position, bounds)
	if not bounds then return true end
	return position.X >= bounds.min.X and position.X <= bounds.max.X
		and position.Y >= bounds.min.Y and position.Y <= bounds.max.Y
		and position.Z >= bounds.min.Z and position.Z <= bounds.max.Z
end

-- Calculate position 5 studs closer to spawn
local function getPositionTowardSpawn(currentPos, spawnPos, distance)
	local direction = (spawnPos - currentPos).Unit
	-- Handle case where positions are the same
	if direction ~= direction then -- NaN check
		return spawnPos
	end
	return currentPos + direction * distance
end

-- Mark player as fully spawned (call after teleporting to spawn)
function SpawnManager.MarkPlayerFullySpawned(player)
	playerFullySpawned[player] = true
	-- Initialize last good position to spawn
	local assignment = playerMapAssignments[player]
	if assignment and assignment.spawn then
		playerLastGoodPositions[player] = assignment.spawn
	end
end

-- Clear fully spawned flag
function SpawnManager.ClearPlayerFullySpawned(player)
	playerFullySpawned[player] = nil
	playerLastGoodPositions[player] = nil
end

-- Start boundary checking
function SpawnManager.StartBoundaryCheck()
	if boundaryCheckConnection then return end

	boundaryCheckConnection = RunService.Heartbeat:Connect(function()
		for player, assignment in playerMapAssignments do
			if not player or not player.Parent then continue end
			if not assignment or not assignment.map then continue end

			-- Only check if player has been fully spawned
			if not playerFullySpawned[player] then continue end

			local character = player.Character
			if not character then continue end

			local rootPart = character:FindFirstChild("HumanoidRootPart")
			if not rootPart then continue end

			local bounds = getMapBounds(assignment.map)
			local currentPos = rootPart.Position

			if isWithinBounds(currentPos, bounds) then
				-- Player is within bounds, update last good position
				playerLastGoodPositions[player] = currentPos
			else
				-- Player left bounds, teleport to last good position but 5 studs closer to spawn
				local lastGoodPos = playerLastGoodPositions[player] or assignment.spawn
				local teleportPos = getPositionTowardSpawn(lastGoodPos, assignment.spawn, 5)

				print("[SpawnManager]", player.Name, "left map bounds, teleporting to last position (5 studs toward spawn)")
				rootPart.CFrame = CFrame.new(teleportPos + Vector3.new(0, 3, 0))

				-- Update last good position to teleport location
				playerLastGoodPositions[player] = teleportPos
			end
		end
	end)

	print("[SpawnManager] Boundary check started")
end

-- Stop boundary checking
function SpawnManager.StopBoundaryCheck()
	if boundaryCheckConnection then
		boundaryCheckConnection:Disconnect()
		boundaryCheckConnection = nil
		print("[SpawnManager] Boundary check stopped")
	end
end

-- Freeze player
function SpawnManager.FreezePlayer(player)
	if not player or not player.Parent then return end
	local character = player.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart then
		rootPart.Anchored = true
	end
end

-- Unfreeze player
function SpawnManager.UnfreezePlayer(player)
	if not player or not player.Parent then return end
	local character = player.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart then
		rootPart.Anchored = false
	end
end

-- Freeze list
function SpawnManager.FreezePlayers(players)
	for _, player in players do
		SpawnManager.FreezePlayer(player)
	end
end

-- Unfreeze list
function SpawnManager.UnfreezePlayers(players)
	for _, player in players do
		SpawnManager.UnfreezePlayer(player)
	end
end

-- Enable lobby
function SpawnManager.EnableLobby()
	lobbyEnabled = true
	if lobbySpawn then
		lobbySpawn.Enabled = true
	end
end

-- Disable lobby
function SpawnManager.DisableLobby()
	lobbyEnabled = false
	if lobbySpawn then
		lobbySpawn.Enabled = false
	end
end

-- Is lobby enabled
function SpawnManager.IsLobbyEnabled()
	return lobbyEnabled
end

-- Spawn at lobby
function SpawnManager.SpawnAtLobby(player)
	if not player or not player.Parent then return end

	SpawnManager.SetPlayerInMatch(player, false)
	SpawnManager.ClearPlayerAssignment(player)

	local character = player.Character
	if not character then
		player:LoadCharacter()
		character = player.CharacterAdded:Wait()
	end

	-- Clear match ID from character for visibility
	if character then
		character:SetAttribute("MatchId", nil)
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart and lobbySpawnPosition then
		rootPart.CFrame = CFrame.new(lobbySpawnPosition + Vector3.new(0, 5, 0))
	end
end

-- Spawn team at position
function SpawnManager.SpawnTeamAt(team, position, teamName, mapFolder)
	if not team or #team == 0 then return end
	print("[SpawnManager] Spawning", teamName or "team", "at", position)

	-- Get match ID from map for visibility tagging
	local matchId = mapFolder and mapFolder:GetAttribute("MatchId")

	for i, player in team do
		if not player or not player.Parent then continue end

		SpawnManager.SetPlayerInMatch(player, true)

		-- Assign to map for boundary checking
		if mapFolder then
			SpawnManager.AssignPlayerToMap(player, mapFolder, position)
		end

		local character = player.Character
		if not character then
			player:LoadCharacter()
			character = player.CharacterAdded:Wait()
		end

		-- Tag character with match ID for visibility filtering
		if matchId and character then
			character:SetAttribute("MatchId", matchId)
		end

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			local offset = Vector3.new((i - 1) * 3, 5, 0)
			rootPart.CFrame = CFrame.new(position + offset)
		end
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.Health = humanoid.MaxHealth
		end

		-- Mark player as fully spawned for boundary checking
		SpawnManager.MarkPlayerFullySpawned(player)
	end
end

-- Spawn player at position
function SpawnManager.SpawnPlayerAt(player, position)
	if not player or not player.Parent then return end
	local character = player.Character
	if not character then
		player:LoadCharacter()
		character = player.CharacterAdded:Wait()
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart then
		rootPart.CFrame = CFrame.new(position + Vector3.new(0, 5, 0))
	end
end

-- Handle character spawn
local function onCharacterAdded(player, character)
	-- Only teleport to lobby if NOT in match
	if lobbyEnabled and lobbySpawnPosition and not SpawnManager.IsPlayerInMatch(player) then
		task.wait(0.1)
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			rootPart.CFrame = CFrame.new(lobbySpawnPosition + Vector3.new(0, 5, 0))
		end
	end

	-- If in match, teleport back to their assigned map spawn
	if SpawnManager.IsPlayerInMatch(player) then
		local assignment = playerMapAssignments[player]
		if assignment and assignment.spawn then
			-- Clear fully spawned flag during respawn to prevent boundary check during teleport
			playerFullySpawned[player] = nil

			-- Re-apply match ID to respawned character for visibility
			if assignment.matchId then
				character:SetAttribute("MatchId", assignment.matchId)
			end

			task.wait(0.1)
			local rootPart = character:FindFirstChild("HumanoidRootPart")
			if rootPart then
				rootPart.CFrame = CFrame.new(assignment.spawn + Vector3.new(0, 5, 0))
			end

			-- Re-mark as fully spawned after teleport
			task.wait(0.1)
			SpawnManager.MarkPlayerFullySpawned(player)
		end
	end
end

-- Player events
local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

local function onPlayerRemoving(player)
	playersInMatch[player] = nil
	playerMapAssignments[player] = nil
	playerLastGoodPositions[player] = nil
	playerFullySpawned[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

print("[SpawnManager] Loaded")
return SpawnManager