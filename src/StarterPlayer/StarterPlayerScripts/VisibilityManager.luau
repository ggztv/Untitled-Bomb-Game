-- LocalScript in StarterPlayerScripts/VisibilityManager
-- Hides maps, bombs, and players from other matches

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local ClientUpdate = ReplicatedStorage:WaitForChild("ClientUpdate")

-- Current match ID (nil when in lobby)
local currentMatchId = nil

-- Cache for hidden objects to avoid re-processing
local hiddenObjects = {}

-- Set transparency of all parts in an instance
local function setInstanceTransparency(instance, transparency)
	if instance:IsA("BasePart") then
		instance.LocalTransparencyModifier = transparency
	end
	for _, child in instance:GetDescendants() do
		if child:IsA("BasePart") then
			child.LocalTransparencyModifier = transparency
		elseif child:IsA("Decal") or child:IsA("Texture") then
			child.Transparency = transparency
		end
	end
end

-- Check if an object belongs to a different match
local function shouldHideObject(obj)
	-- Never hide local player's own character
	if obj == LocalPlayer.Character then
		return false
	end

	local objMatchId = obj:GetAttribute("MatchId")

	-- If we're in lobby (no match), hide all match objects
	if currentMatchId == nil then
		return objMatchId ~= nil
	end

	-- If object has no match ID, don't hide it (lobby objects)
	if objMatchId == nil then
		return false
	end

	-- Hide if match ID doesn't match ours
	return objMatchId ~= currentMatchId
end

-- Process visibility for an object
local function processObjectVisibility(obj)
	if shouldHideObject(obj) then
		if not hiddenObjects[obj] then
			hiddenObjects[obj] = true
			setInstanceTransparency(obj, 1)
		end
	else
		if hiddenObjects[obj] then
			hiddenObjects[obj] = nil
			setInstanceTransparency(obj, 0)
		end
	end
end

-- Scan workspace for objects with MatchId attribute
local function scanWorkspace()
	for _, obj in workspace:GetDescendants() do
		if obj:GetAttribute("MatchId") ~= nil then
			processObjectVisibility(obj)
		end
	end
end

-- Handle new objects being added
workspace.DescendantAdded:Connect(function(obj)
	-- Wait a frame for attributes to be set
	task.defer(function()
		if obj:GetAttribute("MatchId") ~= nil then
			processObjectVisibility(obj)
		end
	end)
end)

-- Handle objects being removed
workspace.DescendantRemoving:Connect(function(obj)
	hiddenObjects[obj] = nil
end)

-- Handle attribute changes
workspace.DescendantAdded:Connect(function(obj)
	obj.AttributeChanged:Connect(function(attrName)
		if attrName == "MatchId" then
			processObjectVisibility(obj)
		end
	end)
end)

-- Listen for match ID updates from server
ClientUpdate.OnClientEvent:Connect(function(action, data)
	if action == "MatchId" then
		local newMatchId = data.matchId

		if currentMatchId ~= newMatchId then
			currentMatchId = newMatchId
			print("[VisibilityManager] Match ID changed to:", currentMatchId or "nil (lobby)")

			-- Re-scan all objects when match changes
			hiddenObjects = {}
			scanWorkspace()
		end
	end
end)

-- Initial scan
task.defer(scanWorkspace)

print("[VisibilityManager] Loaded")
