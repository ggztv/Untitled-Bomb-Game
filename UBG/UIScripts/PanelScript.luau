-- LocalScript in StarterGui/Panels
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Network
local ServerRequest = ReplicatedStorage:WaitForChild("ServerRequest")
local ClientUpdate = ReplicatedStorage:WaitForChild("ClientUpdate")

-- UI References
local Panels = script.Parent
local GameUI = PlayerGui:WaitForChild("GameUI")

local ShopButton = GameUI:WaitForChild("Shop")
local TasksButton = GameUI:WaitForChild("Tasks")

local ShopPanel = Panels:FindFirstChild("Shop")
local TasksPanel = Panels:FindFirstChild("Tasks")

-- Animation config
local ANIM_TIME = 0.15
local SCALE_START = 0.85
local TWEEN_IN = TweenInfo.new(ANIM_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TWEEN_OUT = TweenInfo.new(ANIM_TIME * 0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

-- Center anchor and adjust position
local function centerAnchor(element)
	if not element then return end
	local size = element.Size
	local pos = element.Position
	element.AnchorPoint = Vector2.new(0.5, 0.5)
	element.Position = UDim2.new(
		pos.X.Scale + size.X.Scale / 2,
		pos.X.Offset + size.X.Offset / 2,
		pos.Y.Scale + size.Y.Scale / 2,
		pos.Y.Offset + size.Y.Offset / 2
	)
end

-- Setup panel scales
local function setupPanel(panel)
	if not panel then return nil end

	centerAnchor(panel)

	local scale = panel:FindFirstChild("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Parent = panel
	end

	return scale
end

local ShopScale = setupPanel(ShopPanel)
local TasksScale = setupPanel(TasksPanel)

-- Store original transparency values
local function getDescendantTransparencies(panel)
	local transparencies = {}

	if panel.BackgroundTransparency < 1 then
		transparencies[panel] = {prop = "BackgroundTransparency", value = panel.BackgroundTransparency}
	end

	for _, desc in panel:GetDescendants() do
		if desc:IsA("GuiObject") and desc.BackgroundTransparency < 1 then
			transparencies[desc] = {prop = "BackgroundTransparency", value = desc.BackgroundTransparency}
		elseif desc:IsA("TextLabel") or desc:IsA("TextButton") or desc:IsA("TextBox") then
			if desc.TextTransparency < 1 then
				transparencies[desc] = transparencies[desc] or {}
				transparencies[desc].text = desc.TextTransparency
			end
		elseif desc:IsA("ImageLabel") or desc:IsA("ImageButton") then
			if desc.ImageTransparency < 1 then
				transparencies[desc] = transparencies[desc] or {}
				transparencies[desc].image = desc.ImageTransparency
			end
		end
	end

	return transparencies
end

local ShopTransparencies = ShopPanel and getDescendantTransparencies(ShopPanel) or {}
local TasksTransparencies = TasksPanel and getDescendantTransparencies(TasksPanel) or {}

-- Set all transparencies
local function setAllTransparent(panel, transparencies)
	for obj, data in pairs(transparencies) do
		if data.prop then obj[data.prop] = 1 end
		if data.text then obj.TextTransparency = 1 end
		if data.image then obj.ImageTransparency = 1 end
	end
end

-- Animate transparencies
local function animateTransparencies(transparencies, fadeIn)
	for obj, data in pairs(transparencies) do
		if data.prop then
			TweenService:Create(obj, fadeIn and TWEEN_IN or TWEEN_OUT, {[data.prop] = fadeIn and data.value or 1}):Play()
		end
		if data.text then
			TweenService:Create(obj, fadeIn and TWEEN_IN or TWEEN_OUT, {TextTransparency = fadeIn and data.text or 1}):Play()
		end
		if data.image then
			TweenService:Create(obj, fadeIn and TWEEN_IN or TWEEN_OUT, {ImageTransparency = fadeIn and data.image or 1}):Play()
		end
	end
end

-- Show panel with animation
local function showPanel(panel, scale, transparencies)
	if not panel or not scale then return end

	scale.Scale = SCALE_START
	setAllTransparent(panel, transparencies)
	panel.Visible = true

	TweenService:Create(scale, TWEEN_IN, {Scale = 1}):Play()
	animateTransparencies(transparencies, true)
end

-- Hide panel with animation
local function hidePanel(panel, scale, transparencies)
	if not panel or not scale or not panel.Visible then return end

	TweenService:Create(scale, TWEEN_OUT, {Scale = SCALE_START}):Play()
	animateTransparencies(transparencies, false)

	task.delay(ANIM_TIME * 0.8, function()
		panel.Visible = false
	end)
end

-- Task Frames
local taskFrames = {}

if TasksPanel then
	local Task1Frame = TasksPanel:FindFirstChild("Task1Frame")
	local Task2Frame = TasksPanel:FindFirstChild("Task2Frame")
	local Task3Frame = TasksPanel:FindFirstChild("Task3Frame")

	if Task1Frame and Task2Frame and Task3Frame then
		taskFrames = {
			{
				daily = {
					label = Task1Frame:WaitForChild("Task1"),
					progress = Task1Frame:WaitForChild("Task1Progress")
				},
				bonus = {
					label = Task1Frame:WaitForChild("BTask1"),
					progress = Task1Frame:WaitForChild("BTask1Progress")
				}
			},
			{
				daily = {
					label = Task2Frame:WaitForChild("Task2"),
					progress = Task2Frame:WaitForChild("Task2Progress")
				},
				bonus = {
					label = Task2Frame:WaitForChild("BTask2"),
					progress = Task2Frame:WaitForChild("BTask2Progress")
				}
			},
			{
				daily = {
					label = Task3Frame:WaitForChild("Task3"),
					progress = Task3Frame:WaitForChild("Task3Progress")
				},
				bonus = {
					label = Task3Frame:WaitForChild("BTask3"),
					progress = Task3Frame:WaitForChild("BTask3Progress")
				}
			}
		}
	end
end

-- State
local cachedTaskData = nil
local pendingUpdate = false

-- Update task display
local function updateTaskUI()
	if not cachedTaskData then return end
	if #taskFrames == 0 then return end

	for i, frame in ipairs(taskFrames) do
		local dailyTask = cachedTaskData.daily[i]
		local bonusTask = cachedTaskData.bonus[i]

		if not dailyTask or not bonusTask then continue end

		if dailyTask.completed then
			frame.daily.label.Visible = false
			frame.daily.progress.Visible = false
			frame.bonus.label.Visible = true
			frame.bonus.progress.Visible = true

			frame.bonus.label.Text = bonusTask.name
			frame.bonus.progress.Text = bonusTask.progress .. "/" .. bonusTask.goal

			if bonusTask.completed then
				frame.bonus.label.TextColor3 = Color3.fromRGB(100, 255, 100)
				frame.bonus.progress.TextColor3 = Color3.fromRGB(100, 255, 100)
			else
				frame.bonus.label.TextColor3 = Color3.fromRGB(255, 200, 100)
				frame.bonus.progress.TextColor3 = Color3.fromRGB(255, 200, 100)
			end
		else
			frame.daily.label.Visible = true
			frame.daily.progress.Visible = true
			frame.bonus.label.Visible = false
			frame.bonus.progress.Visible = false

			frame.daily.label.Text = dailyTask.name
			frame.daily.progress.Text = dailyTask.progress .. "/" .. dailyTask.goal
			frame.daily.label.TextColor3 = Color3.fromRGB(255, 255, 255)
			frame.daily.progress.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
	end

	pendingUpdate = false
end

-- Try to update
local function tryUpdate()
	if TasksPanel and TasksPanel.Visible then
		updateTaskUI()
	else
		pendingUpdate = true
	end
end

-- Toggle panels
ShopButton.MouseButton1Click:Connect(function()
	if TasksPanel and TasksPanel.Visible then
		hidePanel(TasksPanel, TasksScale, TasksTransparencies)
	end

	if ShopPanel then
		if ShopPanel.Visible then
			hidePanel(ShopPanel, ShopScale, ShopTransparencies)
		else
			showPanel(ShopPanel, ShopScale, ShopTransparencies)
		end
	end
end)

TasksButton.MouseButton1Click:Connect(function()
	if ShopPanel and ShopPanel.Visible then
		hidePanel(ShopPanel, ShopScale, ShopTransparencies)
	end

	if TasksPanel then
		if TasksPanel.Visible then
			hidePanel(TasksPanel, TasksScale, TasksTransparencies)
		else
			showPanel(TasksPanel, TasksScale, TasksTransparencies)
			if pendingUpdate then
				updateTaskUI()
			end
		end
	end
end)

-- Handle updates
ClientUpdate.OnClientEvent:Connect(function(action, data)
	if action == "Tasks" then
		cachedTaskData = data
		tryUpdate()
	end
end)

-- Hide panels by default
if ShopPanel then ShopPanel.Visible = false end
if TasksPanel then TasksPanel.Visible = false end

print("[PanelsScript] Loaded")