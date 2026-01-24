-- Script in ServerScriptService called "GameInit"
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Load modules
local Modules = script.Parent:WaitForChild("Modules")
local NetworkManager = require(Modules:WaitForChild("NetworkManager"))
local DataManager = require(Modules:WaitForChild("DataManager"))
local TaskManager = require(Modules:WaitForChild("TaskManager"))
local ShopManager = require(Modules:WaitForChild("ShopManager"))
local LoadoutManager = require(Modules:WaitForChild("LoadoutManager"))

-- Initialize modules
DataManager.Init(NetworkManager)
TaskManager.Init(DataManager, NetworkManager)
ShopManager.Init(DataManager, NetworkManager)
LoadoutManager.Init(DataManager, NetworkManager)

-- Make available globally
_G.NetworkManager = NetworkManager
_G.DataManager = DataManager
_G.TaskManager = TaskManager
_G.ShopManager = ShopManager
_G.LoadoutManager = LoadoutManager

-- Debug: Add credits (Studio only)
NetworkManager.RegisterHandler("AddCredits", function(player, amount)
	if RunService:IsStudio() then
		DataManager.AddCredits(player, amount or 10)
		print("[Debug]", player.Name, "added", amount, "credits")
	end
end)

-- Player join/leave
Players.PlayerAdded:Connect(function(player)
	DataManager.Load(player)
	TaskManager.SyncTasks(player)
	LoadoutManager.SyncInventory(player)
	LoadoutManager.SyncLoadout(player)
end)

Players.PlayerRemoving:Connect(function(player)
	DataManager.Cleanup(player)
end)

print("[GameInit] Loaded")