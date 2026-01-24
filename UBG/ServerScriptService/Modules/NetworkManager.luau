-- ModuleScript in ServerScriptService/Modules/NetworkManager
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NetworkManager = {}

local ServerRequest = ReplicatedStorage:WaitForChild("ServerRequest")
local ClientUpdate = ReplicatedStorage:WaitForChild("ClientUpdate")
local ClientNotify = ReplicatedStorage:WaitForChild("ClientNotify")

-- Registered handlers
local handlers = {}

-- Register a handler for an action
function NetworkManager.RegisterHandler(action, callback)
	handlers[action] = callback
end

-- Send update to specific client
function NetworkManager.SendToClient(player, action, data)
	ClientUpdate:FireClient(player, action, data)
end

-- Send update to all clients
function NetworkManager.SendToAll(action, data)
	ClientUpdate:FireAllClients(action, data)
end

-- Send update to list of players
function NetworkManager.SendToPlayers(players, action, data)
	for _, player in players do
		if player and player.Parent then
			ClientUpdate:FireClient(player, action, data)
		end
	end
end

-- Send notification to client
function NetworkManager.Notify(player, message)
	ClientNotify:FireClient(player, message)
end

-- Send notification to all
function NetworkManager.NotifyAll(message)
	ClientNotify:FireAllClients(message)
end

-- Handle incoming requests
ServerRequest.OnServerEvent:Connect(function(player, action, ...)
	local handler = handlers[action]
	if handler then
		handler(player, ...)
	else
		warn("[NetworkManager] Unknown action:", action)
	end
end)

print("[NetworkManager] Loaded")
return NetworkManager