-- ModuleScript in ServerScriptService/Modules/TeamManager
local Players = game:GetService("Players")
local TeamManager = {}

-- State
local teamA = {}
local teamB = {}
local soloMode = false

-- Set solo mode
function TeamManager.SetSoloMode(enabled)
	soloMode = enabled
end

-- Assign players to teams randomly
function TeamManager.Assign(playerList)
	teamA = {}
	teamB = {}

	-- Use provided list or all players
	local allPlayers = playerList or Players:GetPlayers()

	-- Create a copy to shuffle (don't modify original)
	local shuffled = {}
	for _, player in allPlayers do
		table.insert(shuffled, player)
	end

	-- Shuffle the copy
	for i = #shuffled, 2, -1 do
		local j = math.random(i)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end

	-- Alternate assignment
	for i, player in shuffled do
		if i % 2 == 1 then
			table.insert(teamA, player)
		else
			table.insert(teamB, player)
		end
	end

	-- Solo mode: put same player on both teams
	if soloMode and #teamA > 0 and #teamB == 0 then
		table.insert(teamB, teamA[1])
	end

	print("[TeamManager] Assigned teams - A:", #teamA, "B:", #teamB)
	for i, p in teamA do print("  Team A:", p.Name) end
	for i, p in teamB do print("  Team B:", p.Name) end

	return teamA, teamB
end

-- Get teams (returns copies to prevent external modification)
function TeamManager.GetTeams()
	return teamA, teamB
end

-- Check if player is in game
local function isPlayerInGame(player)
	return player and player.Parent == Players
end

-- Check if teams are still valid (remove disconnected players)
function TeamManager.ValidateTeams()
	local teamAValid = false
	local teamBValid = false

	for i = #teamA, 1, -1 do
		if not isPlayerInGame(teamA[i]) then
			table.remove(teamA, i)
		else
			teamAValid = true
		end
	end

	for i = #teamB, 1, -1 do
		if not isPlayerInGame(teamB[i]) then
			table.remove(teamB, i)
		else
			teamBValid = true
		end
	end

	return teamAValid, teamBValid
end

-- Remove player from teams
function TeamManager.RemovePlayer(player)
	local indexA = table.find(teamA, player)
	local indexB = table.find(teamB, player)

	if indexA then table.remove(teamA, indexA) end
	if indexB then table.remove(teamB, indexB) end
end

-- Check if teams have enough players
function TeamManager.HasEnoughPlayers()
	return #teamA > 0 and #teamB > 0
end

-- Get player count
function TeamManager.GetPlayerCount()
	return #Players:GetPlayers()
end

-- Get minimum players required
function TeamManager.GetMinPlayers()
	return soloMode and 1 or 2
end

-- Clear teams
function TeamManager.Clear()
	teamA = {}
	teamB = {}
end

print("[TeamManager] Loaded")
return TeamManager