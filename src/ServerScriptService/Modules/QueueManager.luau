-- ModuleScript in ServerScriptService/Modules/QueueManager
local Players = game:GetService("Players")

local QueueManager = {}

local NetworkManager = nil
local queue = {}
local minPlayers = 2
local matchFoundCallback = nil

-- Multi-match support
local MAX_CONCURRENT_MATCHES = 6
local activeMatchCount = 0
local playerMatchAssignments = {} -- player -> matchId

function QueueManager.Init(networkManager)
	NetworkManager = networkManager

	print("[QueueManager] Registering handlers...")

	-- Register handlers
	NetworkManager.RegisterHandler("JoinQueue", function(player)
		QueueManager.AddToQueue(player)
	end)

	NetworkManager.RegisterHandler("LeaveQueue", function(player)
		QueueManager.RemoveFromQueue(player)
	end)

	print("[QueueManager] Initialized")
end

function QueueManager.SetMinPlayers(min)
	minPlayers = min
end

function QueueManager.SetMatchFoundCallback(callback)
	matchFoundCallback = callback
end

function QueueManager.GetQueueCount()
	return #queue
end

function QueueManager.GetQueuedPlayers()
	return queue
end

function QueueManager.IsInQueue(player)
	return table.find(queue, player) ~= nil
end

-- Multi-match functions
function QueueManager.GetActiveMatchCount()
	return activeMatchCount
end

function QueueManager.CanStartNewMatch()
	return activeMatchCount < MAX_CONCURRENT_MATCHES
end

function QueueManager.IncrementMatchCount()
	activeMatchCount += 1
	print("[QueueManager] Active matches:", activeMatchCount)
end

function QueueManager.DecrementMatchCount()
	activeMatchCount = math.max(0, activeMatchCount - 1)
	print("[QueueManager] Active matches:", activeMatchCount)
end

function QueueManager.AssignPlayerToMatch(player, matchId)
	playerMatchAssignments[player] = matchId
end

function QueueManager.GetPlayerMatch(player)
	return playerMatchAssignments[player]
end

function QueueManager.ClearPlayerMatch(player)
	playerMatchAssignments[player] = nil
end

function QueueManager.IsPlayerInMatch(player)
	return playerMatchAssignments[player] ~= nil
end

local function broadcastToQueue(status, data)
	for _, player in queue do
		if player and player.Parent then
			NetworkManager.SendToClient(player, "Queue", {status = status, data = data})
		end
	end
end

function QueueManager.AddToQueue(player)
	-- Don't allow joining queue if already in a match
	if QueueManager.IsPlayerInMatch(player) then
		return false
	end

	if table.find(queue, player) then
		return false
	end

	table.insert(queue, player)
	print("[QueueManager]", player.Name, "joined queue. Count:", #queue)

	NetworkManager.SendToClient(player, "Queue", {status = "joined", count = #queue})

	-- Check if we can start a match (enough players AND slot available)
	if QueueManager.CanStartNewMatch() and #queue >= minPlayers and matchFoundCallback then
		matchFoundCallback(queue)
	end

	return true
end

function QueueManager.RemoveFromQueue(player)
	local index = table.find(queue, player)
	if not index then
		return false
	end

	table.remove(queue, index)
	print("[QueueManager]", player.Name, "left queue. Count:", #queue)

	NetworkManager.SendToClient(player, "Queue", {status = "left", count = #queue})

	return true
end

function QueueManager.ClearQueue()
	for _, player in queue do
		if player and player.Parent then
			NetworkManager.SendToClient(player, "Queue", {status = "started"})
		end
	end
	queue = {}
end

-- Take players from queue for a match (returns and removes them)
function QueueManager.TakePlayersForMatch(count)
	local taken = {}
	count = math.min(count, #queue)

	for i = 1, count do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			table.insert(taken, player)
			NetworkManager.SendToClient(player, "Queue", {status = "started"})
		end
	end

	return taken
end

function QueueManager.NotifyPlayersGameEnded(players)
	for _, player in players do
		if player and player.Parent then
			QueueManager.ClearPlayerMatch(player)
			NetworkManager.SendToClient(player, "Queue", {status = "ended"})
		end
	end
end

function QueueManager.NotifyAllGameEnded()
	for _, player in Players:GetPlayers() do
		NetworkManager.SendToClient(player, "Queue", {status = "ended"})
	end
end

function QueueManager.NotifyMatchFound()
	broadcastToQueue("found", 10)
end

function QueueManager.NotifyCountdown(seconds)
	broadcastToQueue("countdown", seconds)
end

function QueueManager.CheckQueue()
	-- Check if we can start a new match
	if QueueManager.CanStartNewMatch() and #queue >= minPlayers and matchFoundCallback then
		print("[QueueManager] Queue has enough players and slot available, starting match")
		matchFoundCallback(queue)
	end
end

Players.PlayerRemoving:Connect(function(player)
	QueueManager.RemoveFromQueue(player)
	QueueManager.ClearPlayerMatch(player)
end)

print("[QueueManager] Loaded with multi-match support (max:", MAX_CONCURRENT_MATCHES, ")")
return QueueManager
