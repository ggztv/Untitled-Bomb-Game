-- ModuleScript in ServerScriptService/Modules/QueueManager
local Players = game:GetService("Players")

local QueueManager = {}

local NetworkManager = nil
local queue = {}
local minPlayers = 2
local matchFoundCallback = nil
local matchInProgress = false

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

function QueueManager.IsMatchInProgress()
	return matchInProgress
end

function QueueManager.SetMatchInProgress(inProgress)
	matchInProgress = inProgress
	print("[QueueManager] Match in progress:", inProgress)
end

local function broadcastToQueue(status, data)
	for _, player in queue do
		if player and player.Parent then
			NetworkManager.SendToClient(player, "Queue", {status = status, data = data})
		end
	end
end

function QueueManager.AddToQueue(player)
	if table.find(queue, player) then
		return false
	end

	table.insert(queue, player)
	print("[QueueManager]", player.Name, "joined queue. Count:", #queue)

	NetworkManager.SendToClient(player, "Queue", {status = "joined", count = #queue})

	if not matchInProgress and #queue >= minPlayers and matchFoundCallback then
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

function QueueManager.NotifyPlayersGameEnded(players)
	for _, player in players do
		if player and player.Parent then
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
	if not matchInProgress and #queue >= minPlayers and matchFoundCallback then
		print("[QueueManager] Queue has enough players, starting match")
		matchFoundCallback(queue)
	end
end

Players.PlayerRemoving:Connect(function(player)
	QueueManager.RemoveFromQueue(player)
end)

print("[QueueManager] Loaded")
return QueueManager