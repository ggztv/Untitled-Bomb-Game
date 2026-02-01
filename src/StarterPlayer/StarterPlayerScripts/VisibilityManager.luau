-- LocalScript in StarterPlayerScripts/VisibilityManager
-- Hides maps, bombs, and players from other matches

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local ClientUpdate = ReplicatedStorage:WaitForChild("ClientUpdate")

-- Current match ID (nil when in lobby)
local currentMatchId = nil

-- Track objects that have MatchId attribute (map folders, bombs, characters)
local trackedObjects = {} -- {[obj] = matchId}

-- Get the MatchId for an object (checks object and ancestors)
local function getObjectMatchId(obj)
	-- First check the object itself
	local matchId = obj:GetAttribute("MatchId")
	if matchId then return matchId end

	-- Check ancestors (for parts inside map folders)
	local parent = obj.Parent
	while parent and parent ~= workspace do
		matchId = parent:GetAttribute("MatchId")
		if matchId then return matchId end
		parent = parent.Parent
	end

	return nil
end

-- Check if an object should be hidden based on match ID
local function shouldHideMatchId(matchId)
	if matchId == nil then
		return false -- No match ID = lobby content, always visible
	end

	if currentMatchId == nil then
		return true -- In lobby, hide all match content
	end

	return matchId ~= currentMatchId -- Hide if different match
end

-- Set transparency on a single BasePart
local function setPartTransparency(part, hidden)
	if not part:IsA("BasePart") then return end

	-- Never hide local player's parts
	local character = LocalPlayer.Character
	if character and part:IsDescendantOf(character) then
		return
	end

	part.LocalTransparencyModifier = hidden and 1 or 0
end

-- Set transparency on an instance and all its descendants
local function setInstanceHidden(instance, hidden)
	if instance:IsA("BasePart") then
		setPartTransparency(instance, hidden)
	end

	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			setPartTransparency(descendant, hidden)
		end
	end
end

-- Update visibility for a tracked object
local function updateTrackedObjectVisibility(obj)
	local matchId = trackedObjects[obj]
	if not matchId then return end

	local shouldHide = shouldHideMatchId(matchId)
	setInstanceHidden(obj, shouldHide)
end

-- Update visibility for ALL tracked objects
local function updateAllVisibility()
	print("[VisibilityManager] Updating all visibility, currentMatchId:", currentMatchId or "nil")
	for obj, matchId in trackedObjects do
		if obj and obj.Parent then
			local shouldHide = shouldHideMatchId(matchId)
			setInstanceHidden(obj, shouldHide)
		end
	end
end

-- Start tracking an object with MatchId
local function trackObject(obj)
	local matchId = obj:GetAttribute("MatchId")
	if not matchId then return end

	if not trackedObjects[obj] then
		print("[VisibilityManager] Tracking object:", obj:GetFullName(), "MatchId:", matchId)
		trackedObjects[obj] = matchId

		-- Apply initial visibility
		local shouldHide = shouldHideMatchId(matchId)
		setInstanceHidden(obj, shouldHide)

		-- Listen for new descendants being added to this object
		obj.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("BasePart") then
				local shouldHide = shouldHideMatchId(trackedObjects[obj])
				setPartTransparency(descendant, shouldHide)
			end
		end)
	end
end

-- Stop tracking an object
local function untrackObject(obj)
	if trackedObjects[obj] then
		-- Make visible before removing
		setInstanceHidden(obj, false)
		trackedObjects[obj] = nil
	end
end

-- Scan workspace for objects with MatchId
local function scanWorkspace()
	local count = 0
	for _, obj in workspace:GetDescendants() do
		local matchId = obj:GetAttribute("MatchId")
		if matchId then
			trackObject(obj)
			count = count + 1
		end
	end
	print("[VisibilityManager] Scan complete, tracking", count, "objects")
end

-- Handle new objects being added to workspace
workspace.DescendantAdded:Connect(function(obj)
	-- Wait a frame for attributes to be set
	task.defer(function()
		if obj and obj.Parent then
			local matchId = obj:GetAttribute("MatchId")
			if matchId then
				trackObject(obj)
			else
				-- Check if this part belongs to a tracked parent
				local parentMatchId = getObjectMatchId(obj)
				if parentMatchId and obj:IsA("BasePart") then
					local shouldHide = shouldHideMatchId(parentMatchId)
					setPartTransparency(obj, shouldHide)
				end
			end
		end
	end)
end)

-- Handle objects being removed
workspace.DescendantRemoving:Connect(function(obj)
	trackedObjects[obj] = nil
end)

-- Handle attribute changes
workspace.DescendantAdded:Connect(function(obj)
	obj.AttributeChanged:Connect(function(attrName)
		if attrName == "MatchId" then
			local matchId = obj:GetAttribute("MatchId")
			if matchId then
				trackObject(obj)
			else
				untrackObject(obj)
			end
		end
	end)
end)

-- Also listen for attribute changes on existing objects
for _, obj in workspace:GetDescendants() do
	obj.AttributeChanged:Connect(function(attrName)
		if attrName == "MatchId" then
			local matchId = obj:GetAttribute("MatchId")
			if matchId then
				trackObject(obj)
			else
				untrackObject(obj)
			end
		end
	end)
end

-- Listen for match ID updates from server
ClientUpdate.OnClientEvent:Connect(function(action, data)
	if action == "MatchId" then
		local newMatchId = data.matchId

		if currentMatchId ~= newMatchId then
			print("[VisibilityManager] Match ID changing from", currentMatchId or "nil", "to", newMatchId or "nil")
			currentMatchId = newMatchId

			-- Update visibility for all tracked objects
			updateAllVisibility()

			-- Schedule a refresh to catch late-loading parts
			scheduleRefresh()
		end
	end
end)

-- One-time refresh after match change (catches any parts that loaded late)
local function scheduleRefresh()
	task.delay(1, function()
		for obj, matchId in trackedObjects do
			if obj and obj.Parent then
				local shouldHide = shouldHideMatchId(matchId)
				setInstanceHidden(obj, shouldHide)
			else
				trackedObjects[obj] = nil
			end
		end
	end)
end

-- Initial scan after short delay
task.defer(function()
	task.wait(0.5)
	print("[VisibilityManager] Initial scan...")
	scanWorkspace()
end)

print("[VisibilityManager] Loaded")
