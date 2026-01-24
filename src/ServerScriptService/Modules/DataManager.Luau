-- ModuleScript in ServerScriptService/Modules/DataManager
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local DataManager = {}

local NetworkManager = nil
local playerDataStore = nil
local isStudio = RunService:IsStudio()

-- Try to get DataStore
pcall(function()
	playerDataStore = DataStoreService:GetDataStore("PlayerData_v1")
end)

-- Player data cache
local playerData = {}

-- Default data
local DEFAULT_DATA = {
	coins = 0,
	inventory = {},
	loadout = {},
	maxSlots = 3,
	tasks = {},
	stats = {
		gamesPlayed = 0,
		gamesWon = 0,
		bombsPlanted = 0,
		bombsDefused = 0
	}
}

-- Deep copy
local function deepCopy(original)
	local copy = {}
	for k, v in pairs(original) do
		if type(v) == "table" then
			copy[k] = deepCopy(v)
		else
			copy[k] = v
		end
	end
	return copy
end

-- Initialize
function DataManager.Init(networkManager)
	NetworkManager = networkManager
end

-- Load player data
function DataManager.Load(player)
	local userId = player.UserId
	local data = nil

	if playerDataStore and not isStudio then
		local success, result = pcall(function()
			return playerDataStore:GetAsync("Player_" .. userId)
		end)

		if success and result then
			data = result
		end
	end

	if not data then
		data = deepCopy(DEFAULT_DATA)
	end

	-- Ensure all fields exist
	for key, value in pairs(DEFAULT_DATA) do
		if data[key] == nil then
			if type(value) == "table" then
				data[key] = deepCopy(value)
			else
				data[key] = value
			end
		end
	end

	-- Ensure stats has all fields
	if data.stats then
		for statKey, statValue in pairs(DEFAULT_DATA.stats) do
			if data.stats[statKey] == nil then
				data.stats[statKey] = statValue
			end
		end
	end

	playerData[userId] = data

	-- Sync credits to client
	if NetworkManager then
		NetworkManager.SendToClient(player, "Credits", data.coins)
	end

	print("[DataManager] Loaded data for", player.Name)
	return data
end

-- Save player data
function DataManager.Save(player)
	local userId = player.UserId
	local data = playerData[userId]

	if not data then return end

	if playerDataStore and not isStudio then
		local success, err = pcall(function()
			playerDataStore:SetAsync("Player_" .. userId, data)
		end)

		if not success then
			warn("[DataManager] Failed to save data for", player.Name, err)
		else
			print("[DataManager] Saved data for", player.Name)
		end
	end
end

-- Cleanup
function DataManager.Cleanup(player)
	local userId = player.UserId
	DataManager.Save(player)
	playerData[userId] = nil
end

-- Get data
function DataManager.GetData(player)
	return playerData[player.UserId]
end

-- Credits/Coins
function DataManager.GetCredits(player)
	local data = playerData[player.UserId]
	return data and data.coins or 0
end

function DataManager.GetCoins(player)
	return DataManager.GetCredits(player)
end

function DataManager.AddCredits(player, amount)
	local data = playerData[player.UserId]
	if not data then return end

	data.coins = (data.coins or 0) + amount

	if NetworkManager then
		NetworkManager.SendToClient(player, "Credits", data.coins)
	end

	return data.coins
end

-- Alias for TaskManager compatibility
function DataManager.AddCoins(player, amount)
	return DataManager.AddCredits(player, amount)
end

function DataManager.SpendCredits(player, amount)
	local data = playerData[player.UserId]
	if not data then return false end

	if data.coins < amount then
		return false
	end

	data.coins = data.coins - amount

	if NetworkManager then
		NetworkManager.SendToClient(player, "Credits", data.coins)
	end

	return true
end

function DataManager.SpendCoins(player, amount)
	return DataManager.SpendCredits(player, amount)
end

-- Inventory
function DataManager.GetInventory(player)
	local data = playerData[player.UserId]
	return data and data.inventory or {}
end

function DataManager.AddItem(player, itemName)
	local data = playerData[player.UserId]
	if not data then return false end

	if not data.inventory then
		data.inventory = {}
	end

	table.insert(data.inventory, itemName)
	return true
end

function DataManager.RemoveItem(player, itemName)
	local data = playerData[player.UserId]
	if not data or not data.inventory then return false end

	local index = table.find(data.inventory, itemName)
	if index then
		table.remove(data.inventory, index)
		return true
	end
	return false
end

function DataManager.HasItem(player, itemName)
	local data = playerData[player.UserId]
	if not data or not data.inventory then return false end

	return table.find(data.inventory, itemName) ~= nil
end

-- Loadout
function DataManager.GetLoadout(player)
	local data = playerData[player.UserId]
	return data and data.loadout or {}
end

function DataManager.SetLoadout(player, loadout)
	local data = playerData[player.UserId]
	if not data then return end

	data.loadout = loadout
end

function DataManager.GetMaxSlots(player)
	local data = playerData[player.UserId]
	return data and data.maxSlots or 3
end

-- Stats
function DataManager.GetStats(player)
	local data = playerData[player.UserId]
	return data and data.stats or {}
end

function DataManager.IncrementStat(player, statName, amount)
	local data = playerData[player.UserId]
	if not data then return end

	if not data.stats then
		data.stats = deepCopy(DEFAULT_DATA.stats)
	end

	data.stats[statName] = (data.stats[statName] or 0) + (amount or 1)
end

-- Tasks
function DataManager.GetTaskData(player)
	local data = playerData[player.UserId]
	return data and data.tasks or {}
end

function DataManager.SetTaskData(player, taskData)
	local data = playerData[player.UserId]
	if not data then return end

	data.tasks = taskData
end

print("[DataManager] Loaded")
return DataManager