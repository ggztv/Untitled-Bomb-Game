-- Script in ServerScriptService called "RoundScript"
local Players = game:GetService("Players")

Players.RespawnTime = 0

-- Load modules
local Modules = script.Parent:WaitForChild("Modules")
local MapManager = require(Modules:WaitForChild("MapManager"))
local TeamManager = require(Modules:WaitForChild("TeamManager"))
local SpawnManager = require(Modules:WaitForChild("SpawnManager"))
local QueueManager = require(Modules:WaitForChild("QueueManager"))

-- Wait for globals
repeat task.wait() until _G.NetworkManager
local NetworkManager = _G.NetworkManager

repeat task.wait() until _G.BombHandler
local BombHandler = _G.BombHandler

repeat task.wait() until _G.TaskManager
local TaskManager = _G.TaskManager

repeat task.wait() until _G.LoadoutManager
local LoadoutManager = _G.LoadoutManager

-- Initialize QueueManager
QueueManager.Init(NetworkManager)

-- Config
local PLANTING_TIME = 90
local DEFUSING_TIME = 90
local ROUNDS_TO_WIN = 5
local INTERMISSION_TIME = 10
local MATCH_FOUND_TIME = 3
local LOADOUT_TIME = 10
local SOLO_MODE = false

local MIN_PLAYERS = SOLO_MODE and 1 or 2

TeamManager.SetSoloMode(SOLO_MODE)
QueueManager.SetMinPlayers(MIN_PLAYERS)

local lobbySpawn = workspace:WaitForChild("Lobby"):WaitForChild("House"):WaitForChild("SpawnLocation")
SpawnManager.Init(lobbySpawn)

-- State
local teamAScore = 0
local teamBScore = 0
local currentRound = 0
local gameStarted = false
local skipPlanting = false
local currentPhase = "None"
local roundEnded = false
local matchPlayers = {}
local teamsAssigned = false -- Track if teams have been assigned this match

-- Broadcast to match players
local function broadcastToMatch(phase, timeLeft, scoreA, scoreB)
	currentPhase = phase
	NetworkManager.SendToPlayers(matchPlayers, "Round", {
		phase = phase,
		timeLeft = timeLeft,
		scoreA = scoreA,
		scoreB = scoreB
	})
end

-- Broadcast to all
local function broadcastToAll(phase, timeLeft, scoreA, scoreB)
	currentPhase = phase
	NetworkManager.SendToAll("Round", {
		phase = phase,
		timeLeft = timeLeft,
		scoreA = scoreA,
		scoreB = scoreB
	})
end

-- Broadcast team info
local function broadcastTeams()
	local teamA, teamB = TeamManager.GetTeams()
	print("[RoundScript] Broadcasting teams - A:", #teamA, "B:", #teamB)
	NetworkManager.SendToPlayers(matchPlayers, "Team", {teamA = teamA, teamB = teamB})
end

-- Enable Fuse Cutters
local function enableFuseCutters()
	for _, player in matchPlayers do
		if not player or not player.Parent then continue end

		local backpack = player:FindFirstChild("Backpack")
		local character = player.Character

		local tool = (backpack and backpack:FindFirstChild("Fuse Cutter")) or
			(character and character:FindFirstChild("Fuse Cutter"))

		if tool then
			tool:SetAttribute("Enabled", true)
		end
	end
end

-- Disable Fuse Cutters
local function disableFuseCutters()
	for _, player in matchPlayers do
		if not player or not player.Parent then continue end

		local backpack = player:FindFirstChild("Backpack")
		local character = player.Character

		local tool = (backpack and backpack:FindFirstChild("Fuse Cutter")) or
			(character and character:FindFirstChild("Fuse Cutter"))

		if tool then
			tool:SetAttribute("Enabled", false)
		end
	end
end

-- End round early
local function endRoundEarly(winningTeam)
	if roundEnded then return end
	roundEnded = true

	-- Notify remaining players
	for _, player in matchPlayers do
		if player and player.Parent then
			NetworkManager.Notify(player, "Round cancelled - opponent left")
		end
	end

	if winningTeam == "A" then
		teamAScore += 1
	elseif winningTeam == "B" then
		teamBScore += 1
	end
end

-- Forward declare
local startRound

-- Reset game
local function resetGame()
	print("[RoundScript] === RESETTING GAME ===")
	teamAScore = 0
	teamBScore = 0
	currentRound = 0
	gameStarted = false
	roundEnded = false
	teamsAssigned = false -- Reset team assignment flag

	BombHandler.Reset()
	MapManager.Cleanup()
	MapManager.CleanupPreloaded()
	TeamManager.Clear()

	SpawnManager.StopBoundaryCheck()
	SpawnManager.ClearAllAssignments()
	SpawnManager.EnableLobby()

	for _, player in matchPlayers do
		if player and player.Parent then
			SpawnManager.SpawnAtLobby(player)
		end
	end

	QueueManager.NotifyPlayersGameEnded(matchPlayers)

	local oldMatchPlayers = matchPlayers
	matchPlayers = {}

	QueueManager.SetMatchInProgress(false)

	for _, player in oldMatchPlayers do
		if player and player.Parent then
			NetworkManager.SendToClient(player, "Round", {
				phase = "Waiting",
				timeLeft = 0,
				scoreA = 0,
				scoreB = 0
			})
		end
	end

	QueueManager.CheckQueue()
end

-- Handle early round end
local function handleEarlyEnd()
	task.wait(2)
	BombHandler.SetPhase("Ended")
	disableFuseCutters()
	MapManager.Cleanup()
	BombHandler.Reset()

	SpawnManager.StopBoundaryCheck()
	SpawnManager.ClearAllAssignments()
	SpawnManager.EnableLobby()

	for _, player in matchPlayers do
		if player and player.Parent then
			SpawnManager.SpawnAtLobby(player)
		end
	end

	if teamAScore >= ROUNDS_TO_WIN or teamBScore >= ROUNDS_TO_WIN then
		broadcastToMatch("GameOver", 0, teamAScore, teamBScore)
		task.wait(5)
		resetGame()
		return true
	end

	return false
end

-- Start intermission
local function startIntermission()
	SpawnManager.StopBoundaryCheck()
	SpawnManager.ClearAllAssignments()

	MapManager.Preload()
	MapManager.Place()

	local mapA, mapB = MapManager.GetMaps()
	BombHandler.SetMaps(mapA, mapB)

	for t = INTERMISSION_TIME, 1, -1 do
		broadcastToMatch("Intermission", t, teamAScore, teamBScore)
		task.wait(1)
	end

	pcall(startRound)
end

-- Record game stats
local function recordGameEnd(winningTeam)
	local teamA, teamB = TeamManager.GetTeams()

	for _, player in teamA do
		if player and player.Parent then
			TaskManager.RecordGamePlayed(player)
		end
	end
	for _, player in teamB do
		if player and player.Parent then
			TaskManager.RecordGamePlayed(player)
		end
	end

	if winningTeam == "A" then
		for _, player in teamA do
			if player and player.Parent then
				TaskManager.RecordGameWon(player)
			end
		end
	elseif winningTeam == "B" then
		for _, player in teamB do
			if player and player.Parent then
				TaskManager.RecordGameWon(player)
			end
		end
	end
end

-- Match found callback
local function onMatchFound(queuedPlayers)
	if gameStarted or QueueManager.IsMatchInProgress() then
		print("[RoundScript] Match already in progress, ignoring")
		return
	end

	QueueManager.SetMatchInProgress(true)

	print("[RoundScript] Match found with", #queuedPlayers, "players")

	matchPlayers = table.clone(queuedPlayers)

	MapManager.Preload()
	MapManager.Place()

	local mapA, mapB = MapManager.GetMaps()
	BombHandler.SetMaps(mapA, mapB)

	QueueManager.NotifyMatchFound()

	for t = MATCH_FOUND_TIME, 1, -1 do
		QueueManager.NotifyCountdown(t)
		task.wait(1)

		if QueueManager.GetQueueCount() < MIN_PLAYERS then
			MapManager.Cleanup()
			QueueManager.SetMatchInProgress(false)
			QueueManager.NotifyPlayersGameEnded(matchPlayers)
			matchPlayers = {}
			return
		end
	end

	local stillQueued = QueueManager.GetQueuedPlayers()

	if LoadoutManager.AnyPlayerHasItems(stillQueued) then
		for _, player in matchPlayers do
			if player and player.Parent then
				NetworkManager.SendToClient(player, "Round", {
					phase = "Loadout",
					timeLeft = LOADOUT_TIME,
					scoreA = 0,
					scoreB = 0
				})
			end
		end

		for t = LOADOUT_TIME, 1, -1 do
			for _, player in matchPlayers do
				if player and player.Parent then
					NetworkManager.SendToClient(player, "Round", {
						phase = "Loadout",
						timeLeft = t,
						scoreA = 0,
						scoreB = 0
					})
				end
			end
			task.wait(1)

			if QueueManager.GetQueueCount() < MIN_PLAYERS then
				MapManager.Cleanup()
				QueueManager.SetMatchInProgress(false)
				QueueManager.NotifyPlayersGameEnded(matchPlayers)
				matchPlayers = {}
				return
			end
		end
	else
		print("[RoundScript] No players have items, skipping loadout")
	end

	QueueManager.ClearQueue()
	gameStarted = true

	local roundSuccess, roundErr = pcall(startRound)
	if not roundSuccess then
		warn("[RoundScript] Failed to start round:", roundErr)
		resetGame()
	end
end

QueueManager.SetMatchFoundCallback(onMatchFound)

-- Main round
startRound = function()
	currentRound += 1
	skipPlanting = false
	roundEnded = false

	print("[RoundScript] === Starting Round", currentRound, "===")
	print("[RoundScript] Score - A:", teamAScore, "B:", teamBScore)

	-- Only assign teams ONCE per match (first round)
	local teamA, teamB
	if not teamsAssigned then
		teamA, teamB = TeamManager.Assign(matchPlayers)
		teamsAssigned = true
		print("[RoundScript] Teams assigned for first time this match")
	else
		teamA, teamB = TeamManager.GetTeams()
		print("[RoundScript] Using existing team assignments")
	end

	BombHandler.Reset()

	local mapA, mapB = MapManager.GetMaps()
	BombHandler.SetMaps(mapA, mapB)

	disableFuseCutters()
	SpawnManager.DisableLobby()

	BombHandler.SetAllBombsPlantedCallback(function()
		skipPlanting = true
	end)

	BombHandler.SetTeams(teamA, teamB)
	broadcastTeams()

	if not TeamManager.HasEnoughPlayers() then
		broadcastToMatch("Waiting", 0, teamAScore, teamBScore)
		SpawnManager.EnableLobby()
		resetGame()
		return
	end

	local mapASpawnPos, mapBSpawnPos = MapManager.GetSpawnPositions()

	-- PLANTING: Team A goes to Map B to plant, Team B goes to Map A to plant
	SpawnManager.SpawnTeamAt(teamA, mapBSpawnPos, "Team A", mapB)
	SpawnManager.SpawnTeamAt(teamB, mapASpawnPos, "Team B", mapA)

	BombHandler.SetPhase("Planting")
	BombHandler.GiveBombs()
	SpawnManager.StartBoundaryCheck()

	-- Planting phase
	for t = PLANTING_TIME, 0, -1 do
		if roundEnded or skipPlanting then break end

		local teamAValid, teamBValid = TeamManager.ValidateTeams()
		if not teamAValid then
			endRoundEarly("B")
			break
		elseif not teamBValid then
			endRoundEarly("A")
			break
		end

		broadcastToMatch("Planting", t, teamAScore, teamBScore)
		task.wait(1)
	end

	if roundEnded then
		if handleEarlyEnd() then return end
		startIntermission()
		return
	end

	-- Swapping phase with countdown (DON'T stop boundary check here)
	for t = 3, 1, -1 do
		broadcastToMatch("Swapping", t, teamAScore, teamBScore)
		task.wait(1)
	end

	local teamAValid, teamBValid = TeamManager.ValidateTeams()
	if not teamAValid then
		endRoundEarly("B")
	elseif not teamBValid then
		endRoundEarly("A")
	end

	if roundEnded then
		if handleEarlyEnd() then return end
		startIntermission()
		return
	end

	-- Now stop boundary check briefly to respawn
	SpawnManager.StopBoundaryCheck()

	BombHandler.SetPhase("Defusing")
	BombHandler.RemoveBombTools()
	BombHandler.EnableDefusing()

	teamA, teamB = TeamManager.GetTeams()
	mapASpawnPos, mapBSpawnPos = MapManager.GetSpawnPositions()

	-- DEFUSING: Team A goes to Map A to defuse, Team B goes to Map B to defuse
	SpawnManager.SpawnTeamAt(teamA, mapASpawnPos, "Team A", mapA)
	SpawnManager.SpawnTeamAt(teamB, mapBSpawnPos, "Team B", mapB)

	-- Restart boundary check after spawning
	SpawnManager.StartBoundaryCheck()

	enableFuseCutters()

	-- Defusing phase
	local teamAFinished = false
	local teamBFinished = false
	local teamAFinishTime = nil
	local teamBFinishTime = nil
	local roundWinner = nil

	for t = DEFUSING_TIME, 0, -1 do
		if roundEnded then break end

		broadcastToMatch("Defusing", t, teamAScore, teamBScore)

		local teamAStillValid, teamBStillValid = TeamManager.ValidateTeams()
		if not teamAStillValid then
			endRoundEarly("B")
			break
		elseif not teamBStillValid then
			endRoundEarly("A")
			break
		end

		local mapADefused = BombHandler.AllDefusedOnMapA()
		local mapBDefused = BombHandler.AllDefusedOnMapB()

		if not teamAFinished and mapADefused then
			teamAFinished = true
			teamAFinishTime = t
		end

		if not teamBFinished and mapBDefused then
			teamBFinished = true
			teamBFinishTime = t
		end

		if teamAFinished and teamBFinished then
			if teamAFinishTime == teamBFinishTime then
				roundWinner = "Tie"
			elseif teamAFinishTime > teamBFinishTime then
				roundWinner = "A"
			else
				roundWinner = "B"
			end
			break
		elseif teamAFinished and not teamBFinished then
			roundWinner = "A"
			break
		elseif teamBFinished and not teamAFinished then
			roundWinner = "B"
			break
		end

		task.wait(1)
	end

	if roundEnded then
		if handleEarlyEnd() then return end
		startIntermission()
		return
	end

	-- Determine winner when timer runs out
	if not roundWinner then
		local mapADefused = BombHandler.AllDefusedOnMapA()
		local mapBDefused = BombHandler.AllDefusedOnMapB()
		local remainingA = BombHandler.GetRemainingOnMapA()
		local remainingB = BombHandler.GetRemainingOnMapB()
		local initialA, initialB = BombHandler.GetInitialBombCounts()

		if mapADefused and mapBDefused then
			roundWinner = "Tie"
		elseif mapADefused then
			roundWinner = "A"
		elseif mapBDefused then
			roundWinner = "B"
		else
			-- Timer ran out - count bombs defused (not percentage)
			local teamADefused = initialA - remainingA
			local teamBDefused = initialB - remainingB

			print("[RoundScript] Timer expired - Team A defused:", teamADefused, "Team B defused:", teamBDefused)

			if teamADefused > teamBDefused then
				roundWinner = "A"
			elseif teamBDefused > teamADefused then
				roundWinner = "B"
			else
				-- Equal bombs defused - pick randomly
				roundWinner = math.random(1, 2) == 1 and "A" or "B"
				print("[RoundScript] Tie broken randomly:", roundWinner)
			end
		end
	end

	if roundWinner == "A" then
		teamAScore += 1
		BombHandler.ExplodeMapB()
	elseif roundWinner == "B" then
		teamBScore += 1
		BombHandler.ExplodeMapA()
	else
		-- Tie case (both finished at exact same time)
		local tieWinner = math.random(1, 2) == 1 and "A" or "B"
		if tieWinner == "A" then
			teamAScore += 1
			BombHandler.ExplodeMapB()
		else
			teamBScore += 1
			BombHandler.ExplodeMapA()
		end
		roundWinner = tieWinner
		print("[RoundScript] Simultaneous finish - random winner:", roundWinner)
	end

	print("[RoundScript] Round winner:", roundWinner)
	print("[RoundScript] New score - A:", teamAScore, "B:", teamBScore)

	task.wait(2)

	BombHandler.SetPhase("Ended")
	disableFuseCutters()
	MapManager.Cleanup()
	BombHandler.Reset()

	SpawnManager.StopBoundaryCheck()
	SpawnManager.ClearAllAssignments()
	SpawnManager.EnableLobby()

	for _, player in matchPlayers do
		if player and player.Parent then
			SpawnManager.SpawnAtLobby(player)
		end
	end

	if teamAScore >= ROUNDS_TO_WIN then
		print("[RoundScript] === BLUE TEAM WINS GAME ===")
		broadcastToMatch("GameOver", 0, teamAScore, teamBScore)
		recordGameEnd("A")
		task.wait(5)
		resetGame()
		return
	elseif teamBScore >= ROUNDS_TO_WIN then
		print("[RoundScript] === RED TEAM WINS GAME ===")
		broadcastToMatch("GameOver", 0, teamAScore, teamBScore)
		recordGameEnd("B")
		task.wait(5)
		resetGame()
		return
	end

	startIntermission()
end

-- Player events
Players.PlayerAdded:Connect(function(player)
	print("[RoundScript] Player joined:", player.Name)
end)

Players.PlayerRemoving:Connect(function(player)
	print("[RoundScript] Player left:", player.Name)

	local index = table.find(matchPlayers, player)
	if index then
		table.remove(matchPlayers, index)
	end

	TeamManager.RemovePlayer(player)

	if index then
		broadcastTeams()
	end
end)

-- Initialize
task.defer(function()
	task.wait(2)
	SpawnManager.EnableLobby()
	broadcastToAll("Waiting", 0, 0, 0)
	print("[RoundScript] Ready - waiting for players to queue")
end)

print("[RoundScript] Loaded | Solo Mode:", SOLO_MODE)