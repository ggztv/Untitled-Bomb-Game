-- ModuleScript in ServerScriptService/Modules/ShopManager
local ShopManager = {}

local DataManager = nil
local NetworkManager = nil

-- Shop items
local SHOP_ITEMS = {
	["Mini Bomb"] = {price = 100, description = "Smaller bomb"},
	["Extended Fuse"] = {price = 150, description = "Longer fuse time"},
	["Fast Defuser"] = {price = 200, description = "Defuse faster"},
	["Detector"] = {price = 250, description = "Reveals nearby bombs"},
	["Decoy"] = {price = 175, description = "Place fake bombs"},
	["Camo"] = {price = 225, description = "Harder to see bombs"},
	["Extra Bomb"] = {price = 300, description = "+1 bomb per round"}
}

function ShopManager.Init(dataManager, networkManager)
	DataManager = dataManager
	NetworkManager = networkManager

	-- Register purchase handler
	NetworkManager.RegisterHandler("Purchase", function(player, itemName)
		ShopManager.PurchaseItem(player, itemName)
	end)

	-- Register shop open handler
	NetworkManager.RegisterHandler("GetShop", function(player)
		ShopManager.SendShopData(player)
	end)
end

function ShopManager.GetItems()
	return SHOP_ITEMS
end

function ShopManager.SendShopData(player)
	local inventory = DataManager.GetInventory(player)
	local credits = DataManager.GetCredits(player)

	local shopData = {
		items = SHOP_ITEMS,
		inventory = inventory,
		credits = credits
	}

	NetworkManager.SendToClient(player, "Shop", shopData)
end

function ShopManager.PurchaseItem(player, itemName)
	local item = SHOP_ITEMS[itemName]
	if not item then
		NetworkManager.Notify(player, "Item not found!")
		return false
	end

	if DataManager.HasItem(player, itemName) then
		NetworkManager.Notify(player, "You already own this!")
		return false
	end

	if not DataManager.SpendCredits(player, item.price) then
		NetworkManager.Notify(player, "Not enough credits!")
		return false
	end

	DataManager.AddItem(player, itemName)
	NetworkManager.Notify(player, "Purchased " .. itemName .. "!")

	-- Sync inventory
	local LoadoutManager = _G.LoadoutManager
	if LoadoutManager then
		LoadoutManager.SyncInventory(player)
	end

	return true
end

print("[ShopManager] Loaded")
return ShopManager