-- LocalScript in StarterPlayerScripts/VisibilityManager
-- Hides maps, bombs, and players from other matches

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local ClientUpdate = ReplicatedStorage:WaitForChild("ClientUpdate")

-- Current match ID (nil when in lobby)
local currentMatchId = nil

-- Track all objects we've modified for cleanup
local modifiedObjects = {}

-- Set transparency of all parts in an instance
local function setInstanceTransparency(instance, transparency)
	if instance:IsA("BasePart") then
		instance.LocalTransparencyModifier = transparency
	end
	for _, child in instance:GetDescendants() do
		if child:IsA("BasePart") then
			child.LocalTransparencyModifier = transparency
		elseif child:IsA("Decal") or child:IsA("Texture") then
			-- For decals/textures, we need to track original transparency
			if transparency > 0 then
				if not child:GetAttribute("_OriginalTransparency") then
					child:SetAttribute("_OriginalTransparency", child.Transparency)
				end
				child.Transparency = 1
			else
				local original = child:GetAttribute("_OriginalTransparency")
				if original then
					child.Transparency = original
					child:SetAttribute("_OriginalTransparency", nil)
				end
			end
		end
	end
end

-- Check if an object should be hidden
local function shouldHideObject(obj)
	-- Never hide local player's own character
	if obj == LocalPlayer.Character then
		return false
	end

	local objMatchId = obj:GetAttribute("MatchId")

	-- Object has no match ID = lobby content, always visible
	if objMatchId == nil then
		return false
	end

	-- If we're in lobby (no match), hide all match objects
	if currentMatchId == nil then
		return true
	end

	-- Hide if match ID doesn't match ours
	return objMatchId ~= currentMatchId
end

-- Process visibility for an object
local function processObjectVisibility(obj)
	local shouldHide = shouldHideObject(obj)

	if shouldHide then
		if not modifiedObjects[obj] then
			modifiedObjects[obj] = true
			setInstanceTransparency(obj, 1)
		end
	else
		if modifiedObjects[obj] then
			modifiedObjects[obj] = nil
			setInstanceTransparency(obj, 0)
		end
	end
end

-- Reset all modified objects to visible
local function resetAllObjects()
	for obj, _ in modifiedObjects do
		if obj and obj.Parent then
			setInstanceTransparency(obj, 0)
		end
	end
	modifiedObjects = {}
end

-- Scan workspace for all objects with MatchId attribute
local function scanWorkspace()
	print("[VisibilityManager] Scanning workspace, currentMatchId:", currentMatchId or "nil")
	local count = 0

	for _, obj in workspace:GetDescendants() do
		local matchId = obj:GetAttribute("MatchId")
		if matchId ~= nil then
			count = count + 1
			processObjectVisibility(obj)
		end
	end

	print("[VisibilityManager] Found", count, "objects with MatchId")
end

-- Handle new objects being added
workspace.DescendantAdded:Connect(function(obj)
	-- Wait a frame for attributes to be set
	task.defer(function()
		if obj and obj.Parent then
			local matchId = obj:GetAttribute("MatchId")
			if matchId ~= nil then
				processObjectVisibility(obj)
			end
		end
	end)
end)

-- Handle objects being removed
workspace.DescendantRemoving:Connect(function(obj)
	modifiedObjects[obj] = nil
end)

-- Handle attribute changes on existing objects
local function setupAttributeListener(obj)
	obj.AttributeChanged:Connect(function(attrName)
		if attrName == "MatchId" then
			processObjectVisibility(obj)
		end
	end)
end

-- Setup listeners for existing objects
for _, obj in workspace:GetDescendants() do
	setupAttributeListener(obj)
end

-- Setup listeners for new objects
workspace.DescendantAdded:Connect(function(obj)
	setupAttributeListener(obj)
end)

-- Listen for match ID updates from server
ClientUpdate.OnClientEvent:Connect(function(action, data)
	if action == "MatchId" then
		local newMatchId = data.matchId

		if currentMatchId ~= newMatchId then
			print("[VisibilityManager] Match ID changing from", currentMatchId or "nil", "to", newMatchId or "nil")

			-- Reset all hidden objects before changing match ID
			resetAllObjects()

			currentMatchId = newMatchId

			-- Re-scan with new match ID
			scanWorkspace()
		end
	end
end)

-- Initial scan after short delay to let objects load
task.defer(function()
	task.wait(0.5)
	print("[VisibilityManager] Initial scan...")
	scanWorkspace()
end)

print("[VisibilityManager] Loaded")
