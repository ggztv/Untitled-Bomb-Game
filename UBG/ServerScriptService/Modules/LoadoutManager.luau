-- ModuleScript in ServerScriptService/Modules/LoadoutManager
local LoadoutManager = {}

local DataManager = nil
local NetworkManager = nil

-- Item definitions
local ITEMS = {
	["Mini Bomb"] = {icon = "rbxassetid://0", description = "Smaller bomb"},
	["Extended Fuse"] = {icon = "rbxassetid://0", description = "Longer fuse time"},
	["Fast Defuser"] = {icon = "rbxassetid://0", description = "Defuse faster"},
	["Detector"] = {icon = "rbxassetid://0", description = "Reveals nearby bombs"},
	["Decoy"] = {icon = "rbxassetid://0", description = "Place fake bombs"},
	["Camo"] = {icon = "rbxassetid://0", description = "Harder to see bombs"},
	["Extra Bomb"] = {icon = "rbxassetid://0", description = "+1 bomb per round"}
}

function LoadoutManager.Init(dataManager, networkManager)
	DataManager = dataManager
	NetworkManager = networkManager

	-- Register handlers
	NetworkManager.RegisterHandler("GetInventory", function(player)
		LoadoutManager.SyncInventory(player)
	end)

	NetworkManager.RegisterHandler("GetLoadout", function(player)
		LoadoutManager.SyncLoadout(player)
	end)

	NetworkManager.RegisterHandler("SetLoadout", function(player, newLoadout)
		local inventory = DataManager.GetInventory(player)
		local maxSlots = DataManager.GetMaxSlots(player)

		-- Validate loadout
		local validLoadout = {}
		for i, itemName in ipairs(newLoadout) do
			if i > maxSlots then break end
			if table.find(inventory, itemName) and not table.find(validLoadout, itemName) then
				table.insert(validLoadout, itemName)
			end
		end

		DataManager.SetLoadout(player, validLoadout)
		LoadoutManager.SyncLoadout(player)
		print("[LoadoutManager]", player.Name, "set loadout:", table.concat(validLoadout, ", "))
	end)
end

function LoadoutManager.PlayerHasItems(player)
	local inventory = DataManager.GetInventory(player)
	return #inventory > 0
end

function LoadoutManager.AnyPlayerHasItems(players)
	for _, player in players do
		if LoadoutManager.PlayerHasItems(player) then
			return true
		end
	end
	return false
end

function LoadoutManager.GetLoadout(player)
	return DataManager.GetLoadout(player)
end

function LoadoutManager.GetItemInfo(itemName)
	return ITEMS[itemName]
end

function LoadoutManager.GetAllItems()
	return ITEMS
end

function LoadoutManager.SyncInventory(player)
	local inventory = DataManager.GetInventory(player)
	local maxSlots = DataManager.GetMaxSlots(player)

	NetworkManager.SendToClient(player, "Inventory", {
		items = inventory,
		definitions = ITEMS,
		maxSlots = maxSlots
	})
end

function LoadoutManager.SyncLoadout(player)
	local loadout = DataManager.GetLoadout(player)
	local maxSlots = DataManager.GetMaxSlots(player)

	NetworkManager.SendToClient(player, "Loadout", {
		loadout = loadout,
		maxSlots = maxSlots
	})
end

print("[LoadoutManager] Loaded")
return LoadoutManager