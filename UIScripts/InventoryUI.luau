-- LocalScript in StarterGui/Inventory
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local ClientUpdate = ReplicatedStorage:WaitForChild("ClientUpdate")

-- UI References
local Inventory = script.Parent
local frames = {
	Inventory:WaitForChild("InvFrame1"),
	Inventory:WaitForChild("InvFrame2"),
	Inventory:WaitForChild("InvFrame3"),
	Inventory:WaitForChild("InvFrame4")
}
local slots = {
	frames[1]:WaitForChild("InvSlot1"),
	frames[2]:WaitForChild("InvSlot2"),
	frames[3]:WaitForChild("InvSlot3"),
	frames[4]:WaitForChild("InvSlot4")
}

-- Store original positions for centering
local originalFramePositions = {}
for i, frame in ipairs(frames) do
	originalFramePositions[i] = frame.Position
end

-- Image IDs for tools
local toolImages = {
	["Bomb"] = "rbxassetid://138568293249622",
	["Fuse Cutter"] = "rbxassetid://98524059070554"
}

-- Tool order priority (lower = first)
local toolOrder = {
	["Bomb"] = 1,
	["Fuse Cutter"] = 2
}

-- Config
local TWEEN_TIME = 0.15
local SELECTED_SCALE = 1.15
local SLOT_SELECTED_SCALE = 1.05
local UNSELECTED_TRANSPARENCY = 0.5
local SCREEN_CENTER = 0.475

-- State
local inGame = false
local selectedSlot = 1
local currentTools = {}
local slotsSetup = false

-- Create UIScale for frames
for i, frame in ipairs(frames) do
	local scale = frame:FindFirstChild("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "UIScale"
		scale.Parent = frame
	end
end

-- Create UIScale for slots
for i, slot in ipairs(slots) do
	local scale = slot:FindFirstChild("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "UIScale"
		scale.Parent = slot
	end
	slot.BackgroundTransparency = 1
end

-- Tween helper
local function tween(object, properties, duration)
	local t = TweenService:Create(object, TweenInfo.new(duration or TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties)
	t:Play()
	return t
end

-- Play sound
local function playSound()
	if _G.SoundManager then
		_G.SoundManager.Play("ButtonClick")
	end
end

-- Center visible frames
local function centerFrames(visibleCount)
	if visibleCount == 0 then return end

	-- Reset all to original first
	for i, frame in ipairs(frames) do
		frame.Position = originalFramePositions[i]
	end

	if visibleCount == 4 then return end

	-- Get center of visible frames group
	local firstPos = originalFramePositions[1].X.Scale
	local lastPos = originalFramePositions[visibleCount].X.Scale
	local groupCenter = (firstPos + lastPos) / 2

	-- Calculate offset to center
	local offset = SCREEN_CENTER - groupCenter

	-- Apply offset to visible frames
	for i = 1, visibleCount do
		local orig = originalFramePositions[i]
		frames[i].Position = UDim2.new(orig.X.Scale + offset, orig.X.Offset, orig.Y.Scale, orig.Y.Offset)
	end
end

-- Setup image for a tool
local function setupSlotImage(slot, toolName)
	local imageLabel = slot:FindFirstChildWhichIsA("ImageLabel")
	if not imageLabel then
		warn("[InventoryUI] No ImageLabel in", slot.Name)
		return
	end

	local imageId = toolImages[toolName]
	if imageId then
		imageLabel.Image = imageId
		imageLabel.Visible = true
	else
		imageLabel.Image = ""
		imageLabel.Visible = false
	end
end

-- Clear slot image
local function clearSlot(slot)
	local imageLabel = slot:FindFirstChildWhichIsA("ImageLabel")
	if imageLabel then
		imageLabel.Image = ""
		imageLabel.Visible = false
	end
end

-- Get tools from backpack and character (sorted)
local function getPlayerTools()
	local tools = {}
	local character = LocalPlayer.Character
	local backpack = LocalPlayer:FindFirstChild("Backpack")

	if backpack then
		for _, tool in backpack:GetChildren() do
			if tool:IsA("Tool") then
				table.insert(tools, tool)
			end
		end
	end

	if character then
		for _, tool in character:GetChildren() do
			if tool:IsA("Tool") then
				table.insert(tools, tool)
			end
		end
	end

	table.sort(tools, function(a, b)
		local orderA = toolOrder[a.Name] or 99
		local orderB = toolOrder[b.Name] or 99
		return orderA < orderB
	end)

	return tools
end

-- Find tool by name
local function findToolByName(name)
	local character = LocalPlayer.Character
	local backpack = LocalPlayer:FindFirstChild("Backpack")

	if backpack then
		local tool = backpack:FindFirstChild(name)
		if tool and tool:IsA("Tool") then
			return tool
		end
	end

	if character then
		local tool = character:FindFirstChild(name)
		if tool and tool:IsA("Tool") then
			return tool
		end
	end

	return nil
end

-- Equip tool by index
local function equipTool(index)
	local tool = currentTools[index]
	if not tool then return end

	local character = LocalPlayer.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	local actualTool = findToolByName(tool.Name)
	if not actualTool then return end

	local backpack = LocalPlayer:FindFirstChild("Backpack")
	if actualTool.Parent == backpack then
		humanoid:EquipTool(actualTool)
	end
end

-- Update slot visuals
local function updateSlotVisuals()
	local toolCount = #currentTools

	centerFrames(toolCount)

	for i, frame in ipairs(frames) do
		local slot = slots[i]
		local frameScale = frame:FindFirstChild("UIScale")
		local slotScale = slot:FindFirstChild("UIScale")

		if i > toolCount then
			frame.Visible = false
			continue
		end

		frame.Visible = inGame

		if not inGame then continue end

		if i == selectedSlot then
			if frameScale then tween(frameScale, {Scale = SELECTED_SCALE}) end
			if slotScale then tween(slotScale, {Scale = SLOT_SELECTED_SCALE / SELECTED_SCALE}) end
			tween(frame, {BackgroundTransparency = 0})
		else
			if frameScale then tween(frameScale, {Scale = 1}) end
			if slotScale then tween(slotScale, {Scale = 1}) end
			tween(frame, {BackgroundTransparency = UNSELECTED_TRANSPARENCY})
		end
	end
end

-- Setup slots
local function setupSlots()
	if slotsSetup then return end

	currentTools = getPlayerTools()

	for i, slot in ipairs(slots) do
		local tool = currentTools[i]
		if tool then
			setupSlotImage(slot, tool.Name)
		else
			clearSlot(slot)
		end
	end

	slotsSetup = true
	selectedSlot = 1
	updateSlotVisuals()

	task.defer(function()
		equipTool(1)
	end)
end

-- Refresh tool list
local function refreshToolList()
	currentTools = getPlayerTools()

	-- Update slot images
	for i, slot in ipairs(slots) do
		local tool = currentTools[i]
		if tool then
			setupSlotImage(slot, tool.Name)
		else
			clearSlot(slot)
		end
	end

	if selectedSlot > #currentTools and #currentTools > 0 then
		selectedSlot = #currentTools
	elseif #currentTools == 0 then
		selectedSlot = 1
	end

	updateSlotVisuals()

	-- Equip first available tool
	task.defer(function()
		equipTool(selectedSlot)
	end)
end

-- Select slot
local function selectSlot(slotNum)
	if not inGame then return end
	if slotNum < 1 or slotNum > #currentTools then return end
	if slotNum == selectedSlot then return end

	selectedSlot = slotNum
	playSound()
	updateSlotVisuals()
	equipTool(slotNum)
end

-- Show/hide inventory
local function setVisible(visible)
	if visible and not inGame then
		inGame = true
		slotsSetup = false
		setupSlots()
	elseif visible and inGame then
		updateSlotVisuals()
	elseif not visible then
		inGame = false
		for _, frame in frames do
			frame.Visible = false
		end
		slotsSetup = false
	end
end

-- Click handlers
for i, slot in ipairs(slots) do
	slot.MouseButton1Click:Connect(function()
		selectSlot(i)
	end)
end

for i, frame in ipairs(frames) do
	frame.MouseButton1Click:Connect(function()
		selectSlot(i)
	end)
end

-- Keyboard input
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if not inGame then return end

	if input.KeyCode == Enum.KeyCode.One then
		selectSlot(1)
	elseif input.KeyCode == Enum.KeyCode.Two then
		selectSlot(2)
	elseif input.KeyCode == Enum.KeyCode.Three then
		selectSlot(3)
	elseif input.KeyCode == Enum.KeyCode.Four then
		selectSlot(4)
	end
end)

-- Listen for tool changes
local function connectToolEvents()
	local backpack = LocalPlayer:WaitForChild("Backpack")

	backpack.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and inGame then
			refreshToolList()
		end
	end)

	backpack.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") and inGame then
			refreshToolList()
		end
	end)
end

LocalPlayer.CharacterAdded:Connect(function(character)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and inGame then
			refreshToolList()
		end
	end)

	character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") and inGame then
			refreshToolList()
		end
	end)
end)

if LocalPlayer.Character then
	LocalPlayer.Character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and inGame then
			refreshToolList()
		end
	end)

	LocalPlayer.Character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") and inGame then
			refreshToolList()
		end
	end)
end

connectToolEvents()

-- Listen for game events
ClientUpdate.OnClientEvent:Connect(function(action, data)
	if action == "Round" then
		local phase = data.phase
		if phase == "Waiting" or phase == "Intermission" or phase == "GameOver" then
			setVisible(false)
		else
			setVisible(true)
		end
	elseif action == "Queue" then
		if data.status == "started" then
			setVisible(true)
		elseif data.status == "ended" then
			setVisible(false)
		end
	end
end)

-- Hide initially
for _, frame in frames do
	frame.Visible = false
end

print("[InventoryUI] Loaded")