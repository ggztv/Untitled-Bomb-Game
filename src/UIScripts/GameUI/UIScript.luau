-- LocalScript in StarterGui/GameUI
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

if LocalPlayer:GetAttribute("GameUILoaded") then
	script:Destroy()
	return
end
LocalPlayer:SetAttribute("GameUILoaded", true)

local screenGui = script.Parent
if screenGui:IsA("ScreenGui") then
	screenGui.ResetOnSpawn = false
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")

StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

-- Network
local ServerRequest = ReplicatedStorage:WaitForChild("ServerRequest")
local ClientUpdate = ReplicatedStorage:WaitForChild("ClientUpdate")
local ClientNotify = ReplicatedStorage:WaitForChild("ClientNotify")

-- UI References
local GameUI = script.Parent
local Topbar = GameUI:WaitForChild("Topbar")

local BlueTeamCounter = Topbar:WaitForChild("BlueTeamCounter")
local BluePlayerIcon = BlueTeamCounter:WaitForChild("PlayerIcon")
local BlueScore = BlueTeamCounter:WaitForChild("Score")

local Timer = Topbar:WaitForChild("Timer")
local TimeLeft = Timer:WaitForChild("TimeLeft")

local RedTeamCounter = Topbar:WaitForChild("RedTeamCounter")
local RedPlayerIcon = RedTeamCounter:WaitForChild("PlayerIcon")
local RedScore = RedTeamCounter:WaitForChild("Score")

local PrimaryNotification = GameUI:WaitForChild("PrimaryNotification")
local PrimaryText = PrimaryNotification:WaitForChild("Text")
local PrimarySubtext = PrimaryNotification:WaitForChild("Subtext")
local PrimaryScale = PrimaryNotification:FindFirstChild("UIScale") or Instance.new("UIScale", PrimaryNotification)

local Notification = GameUI:WaitForChild("Notification")
local NotificationText = Notification:WaitForChild("Text")
local NotificationSubtext = Notification:WaitForChild("Subtext")
local NotificationScale = Notification:FindFirstChild("UIScale") or Instance.new("UIScale", Notification)

local MicroNotification = GameUI:WaitForChild("MicroNotification")
local MicroScale = MicroNotification:FindFirstChild("UIScale") or Instance.new("UIScale", MicroNotification)

local BombsLeftFrame = GameUI:WaitForChild("BombsLeft")
local BombsLeftText = BombsLeftFrame:WaitForChild("BombsLeft")

local ShopButton = GameUI:WaitForChild("Shop")
local TasksButton = GameUI:WaitForChild("Tasks")
local CreditCounter = GameUI:WaitForChild("CreditCounter")
local CreditCount = CreditCounter:WaitForChild("CreditCount")
local PlayButton = GameUI:WaitForChild("Play")
local PlayButtonLabel = PlayButton:WaitForChild("Label")

-- Hide everything initially
PrimaryNotification.Visible = false
Notification.Visible = false
MicroNotification.Visible = false
Topbar.Visible = false
BombsLeftFrame.Visible = false

-- Animation config (optimized for snappier feel)
local ANIM_FADE_TIME = 0.08
local ANIM_SCALE_TIME = 0.06
local ANIM_MOVE_TIME = 0.08
local ANIM_OFFSET = UDim2.new(0, 0, -0.03, 0)
local NOTIFICATION_DURATION = 3

-- Button animation config
local BTN_HOVER_SCALE = 1.05
local BTN_CLICK_SCALE = 0.95
local BTN_TWEEN_TIME = 0.06

-- Wait for SoundManager
local SoundManager
task.spawn(function()
	repeat task.wait() until _G.SoundManager
	SoundManager = _G.SoundManager
end)

local function playClick()
	if SoundManager then
		SoundManager.Play("ButtonClick")
	end
end

-- Helpers
local function safeCancel(thread)
	if thread then pcall(function() task.cancel(thread) end) end
	return nil
end

local function tween(object, properties, duration, easingStyle, easingDirection)
	local info = TweenInfo.new(duration or 0.3, easingStyle or Enum.EasingStyle.Quad, easingDirection or Enum.EasingDirection.Out)
	local t = TweenService:Create(object, info, properties)
	t:Play()
	return t
end

-- Center anchor and adjust position
local function centerAnchor(element)
	if not element then return end
	-- Skip if already centered
	if element.AnchorPoint.X == 0.5 and element.AnchorPoint.Y == 0.5 then return end

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

-- Center panels
centerAnchor(PrimaryNotification)
centerAnchor(Notification)

-- Store original values AFTER centering
local PrimaryOriginalPosition = PrimaryNotification.Position
local PrimaryOriginalBgTransparency = PrimaryNotification.BackgroundTransparency
local PrimaryTextOriginalTransparency = PrimaryText.TextTransparency
local PrimarySubtextOriginalTransparency = PrimarySubtext.TextTransparency

local NotificationOriginalPosition = Notification.Position
local NotificationOriginalBgTransparency = Notification.BackgroundTransparency
local NotificationTextOriginalTransparency = NotificationText.TextTransparency
local NotificationSubtextOriginalTransparency = NotificationSubtext.TextTransparency

-- Button animations
local function applyButtonAnimation(button, callback)
	local scale = button:FindFirstChild("UIScale") or Instance.new("UIScale", button)
	scale.Scale = 1

	centerAnchor(button)

	button.MouseEnter:Connect(function()
		tween(scale, {Scale = BTN_HOVER_SCALE}, BTN_TWEEN_TIME)
	end)

	button.MouseLeave:Connect(function()
		tween(scale, {Scale = 1}, BTN_TWEEN_TIME)
	end)

	button.MouseButton1Down:Connect(function()
		tween(scale, {Scale = BTN_CLICK_SCALE}, BTN_TWEEN_TIME * 0.5)
	end)

	button.MouseButton1Up:Connect(function()
		tween(scale, {Scale = BTN_HOVER_SCALE}, BTN_TWEEN_TIME * 0.5)
	end)

	if callback then
		button.MouseButton1Click:Connect(function()
			playClick()
			callback()
		end)
	else
		button.MouseButton1Click:Connect(function()
			playClick()
		end)
	end
end

local function animateIn(frame, textLabel, subtextLabel, scale, originalPosition, originalBgTransparency, originalTextTransparency, originalSubtextTransparency)
	frame.Visible = true
	frame.BackgroundTransparency = 1
	frame.Position = originalPosition + ANIM_OFFSET
	scale.Scale = 0.8
	textLabel.TextTransparency = 1
	if subtextLabel then subtextLabel.TextTransparency = 1 end

	tween(frame, {BackgroundTransparency = originalBgTransparency}, ANIM_FADE_TIME)
	tween(textLabel, {TextTransparency = originalTextTransparency}, ANIM_FADE_TIME)
	if subtextLabel and subtextLabel.Visible then
		tween(subtextLabel, {TextTransparency = originalSubtextTransparency}, ANIM_FADE_TIME)
	end

	task.wait(ANIM_FADE_TIME * 0.5)
	tween(scale, {Scale = 1}, ANIM_SCALE_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	task.wait(ANIM_SCALE_TIME * 0.5)
	tween(frame, {Position = originalPosition}, ANIM_MOVE_TIME)
end

local function animateOut(frame, textLabel, subtextLabel, scale, originalPosition)
	tween(frame, {Position = originalPosition + ANIM_OFFSET}, ANIM_MOVE_TIME)
	task.wait(ANIM_MOVE_TIME * 0.5)
	tween(scale, {Scale = 0.8}, ANIM_SCALE_TIME)
	task.wait(ANIM_SCALE_TIME * 0.5)
	tween(frame, {BackgroundTransparency = 1}, ANIM_FADE_TIME)
	tween(textLabel, {TextTransparency = 1}, ANIM_FADE_TIME)
	if subtextLabel then tween(subtextLabel, {TextTransparency = 1}, ANIM_FADE_TIME) end
	task.wait(ANIM_FADE_TIME)
	frame.Visible = false
end

local function formatTime(seconds)
	local mins = math.floor(seconds / 60)
	local secs = seconds % 60
	return string.format("%d:%02d", mins, secs)
end

local function getPlayerThumbnail(player)
	if not player then return "" end
	local userId = player.UserId
	if userId <= 0 then userId = 1 end
	return "rbxthumb://type=AvatarHeadShot&id=" .. userId .. "&w=150&h=150"
end

local function updateTeamAvatars(teamA, teamB)
	if #teamA > 0 then
		BluePlayerIcon.Image = getPlayerThumbnail(teamA[1])
	else
		BluePlayerIcon.Image = ""
	end

	if #teamB > 0 then
		RedPlayerIcon.Image = getPlayerThumbnail(teamB[1])
	else
		RedPlayerIcon.Image = ""
	end
end

-- Notification state
local hidePrimaryThread, hideNotificationThread = nil, nil
local primaryVisible, notificationVisible = false, false
local primaryQueue, notificationQueue = {}, {}
local processingPrimary, processingNotification = false, false
local currentPhase = ""

local showPrimaryNotification, hidePrimaryNotification, showNotification, hideNotification
local queuePrimaryNotification, queueNotification, processPrimaryQueue, processNotificationQueue

hidePrimaryNotification = function()
	if not primaryVisible then return end
	primaryVisible = false
	processingPrimary = false
	animateOut(PrimaryNotification, PrimaryText, PrimarySubtext, PrimaryScale, PrimaryOriginalPosition)
end

showPrimaryNotification = function(title, subtitle, duration)
	hidePrimaryThread = safeCancel(hidePrimaryThread)
	Topbar.Visible = false

	PrimaryText.Text = title
	if subtitle and subtitle ~= "" then
		PrimarySubtext.Text = subtitle
		PrimarySubtext.Visible = true
	else
		PrimarySubtext.Visible = false
	end

	if not primaryVisible then
		primaryVisible = true
		animateIn(PrimaryNotification, PrimaryText, PrimarySubtext, PrimaryScale, PrimaryOriginalPosition, PrimaryOriginalBgTransparency, PrimaryTextOriginalTransparency, PrimarySubtextOriginalTransparency)
	end

	if duration then
		hidePrimaryThread = task.delay(duration, function()
			hidePrimaryNotification()
			task.wait(0.2)
			processPrimaryQueue()
		end)
	end
end

hideNotification = function()
	if not notificationVisible then return end
	notificationVisible = false
	processingNotification = false
	animateOut(Notification, NotificationText, NotificationSubtext, NotificationScale, NotificationOriginalPosition)
end

showNotification = function(title, subtitle, duration)
	hideNotificationThread = safeCancel(hideNotificationThread)

	NotificationText.Text = title
	if subtitle and subtitle ~= "" then
		NotificationSubtext.Text = subtitle
		NotificationSubtext.Visible = true
	else
		NotificationSubtext.Visible = false
	end

	if not notificationVisible then
		notificationVisible = true
		animateIn(Notification, NotificationText, NotificationSubtext, NotificationScale, NotificationOriginalPosition, NotificationOriginalBgTransparency, NotificationTextOriginalTransparency, NotificationSubtextOriginalTransparency)
	end

	hideNotificationThread = task.delay(duration or NOTIFICATION_DURATION, function()
		hideNotification()
		task.wait(0.2)
		processNotificationQueue()
	end)
end

processPrimaryQueue = function()
	if processingPrimary or #primaryQueue == 0 then return end
	processingPrimary = true
	local next = table.remove(primaryQueue, 1)
	showPrimaryNotification(next.title, next.subtitle, next.duration)
end

processNotificationQueue = function()
	if processingNotification or #notificationQueue == 0 then return end
	processingNotification = true
	local next = table.remove(notificationQueue, 1)
	showNotification(next.title, next.subtitle, next.duration)
end

queuePrimaryNotification = function(title, subtitle, duration)
	notificationQueue = {}
	if notificationVisible then hideNotification() end
	processingNotification = false
	Topbar.Visible = false
	table.insert(primaryQueue, {title = title, subtitle = subtitle, duration = duration})
	processPrimaryQueue()
end

queueNotification = function(title, subtitle, duration)
	if primaryVisible then
		hidePrimaryNotification()
		primaryQueue = {}
		task.wait(0.15)
	end

	Topbar.Visible = true
	table.insert(notificationQueue, {title = title, subtitle = subtitle, duration = duration})
	processNotificationQueue()
end

local function clearAllNotifications()
	primaryQueue, notificationQueue = {}, {}
	processingPrimary, processingNotification = false, false
	hidePrimaryThread = safeCancel(hidePrimaryThread)
	hideNotificationThread = safeCancel(hideNotificationThread)
	if primaryVisible then hidePrimaryNotification() end
	if notificationVisible then hideNotification() end
end

-- MicroNotification (small red text for quick failure messages) with stacking
local MICRO_ANIM_TIME = 0.08
local MICRO_DISPLAY_TIME = 2
local MICRO_STACK_SPACING = 5
local MICRO_MAX_STACKS = 5

local microStack = {} -- Active notification clones
local microQueue = {} -- Queued messages waiting to display
local microOriginalPosition = MicroNotification.Position
local microOriginalSize = MicroNotification.AbsoluteSize

-- Forward declare
local displayMicroNotification

-- Get Y offset for stack position
local function getMicroStackOffset(stackIndex)
	return (microOriginalSize.Y + MICRO_STACK_SPACING) * stackIndex
end

-- Update positions of all stacked notifications
local function updateMicroStackPositions()
	for i, entry in ipairs(microStack) do
		local offset = getMicroStackOffset(i - 1)
		entry.label.Position = UDim2.new(
			microOriginalPosition.X.Scale,
			microOriginalPosition.X.Offset,
			microOriginalPosition.Y.Scale,
			microOriginalPosition.Y.Offset - offset
		)
	end
end

-- Remove a notification from the stack
local function removeMicroFromStack(entry)
	local index = table.find(microStack, entry)
	if index then
		table.remove(microStack, index)
	end

	-- Animate out and destroy
	local scale = entry.label:FindFirstChild("UIScale")
	if scale then
		local t = tween(scale, {Scale = 0}, MICRO_ANIM_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		t.Completed:Wait()
	end
	entry.label:Destroy()

	-- Update remaining stack positions
	updateMicroStackPositions()

	-- Process queue if there's room
	if #microStack < MICRO_MAX_STACKS and #microQueue > 0 then
		local nextMessage = table.remove(microQueue, 1)
		task.spawn(function()
			displayMicroNotification(nextMessage)
		end)
	end
end

-- Display a micro notification (internal - doesn't play sound)
displayMicroNotification = function(message)
	-- Clone the original notification
	local clone = MicroNotification:Clone()
	clone.Text = message
	clone.Visible = true
	clone.Parent = MicroNotification.Parent

	-- Add UIScale if not present
	local scale = clone:FindFirstChild("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Parent = clone
	end
	scale.Scale = 0

	-- Add to stack
	local entry = {
		label = clone,
		hideThread = nil
	}
	table.insert(microStack, entry)

	-- Update all positions
	updateMicroStackPositions()

	-- Animate scale in (fast pop)
	tween(scale, {Scale = 1}, MICRO_ANIM_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	-- Schedule hide
	entry.hideThread = task.delay(MICRO_DISPLAY_TIME, function()
		removeMicroFromStack(entry)
	end)
end

-- Public function to show micro notification (plays sound immediately)
local function showMicroNotification(message)
	-- Play failure sound immediately (before any queueing)
	if SoundManager then
		SoundManager.Play("Failure")
	end

	-- Check if we can display or need to queue
	if #microStack < MICRO_MAX_STACKS then
		displayMicroNotification(message)
	else
		-- Queue for later
		table.insert(microQueue, message)
	end
end

-- Expose globally so other scripts can show micro notifications
_G.ShowMicroNotification = showMicroNotification

-- Hide the original template
MicroNotification.Visible = false

-- Queue state
local inQueue = false
local queueStartTime = 0
local queueTimerThread = nil

local function formatQueueTime(seconds)
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function stopQueueTimer()
	if queueTimerThread then pcall(function() task.cancel(queueTimerThread) end) end
	queueTimerThread = nil
end

local function startQueueTimer()
	stopQueueTimer()
	queueStartTime = tick()
	queueTimerThread = task.spawn(function()
		while inQueue do
			local elapsed = math.floor(tick() - queueStartTime)
			PrimarySubtext.Text = "Finding an opponent (" .. formatQueueTime(elapsed) .. ")"
			task.wait(1)
		end
	end)
end

-- Handle server updates
ClientUpdate.OnClientEvent:Connect(function(action, data)
	if action == "Round" then
		local phase = data.phase
		local timeLeft = data.timeLeft
		local scoreA = data.scoreA
		local scoreB = data.scoreB

		TimeLeft.Text = (timeLeft and timeLeft > 0) and formatTime(timeLeft) or "-:--"
		BlueScore.Text = tostring(scoreA)
		RedScore.Text = tostring(scoreB)

		if phase ~= currentPhase then
			currentPhase = phase

			if phase == "Waiting" then
				clearAllNotifications()
				Topbar.Visible = false
			elseif phase == "Loadout" then
				Topbar.Visible = true
			else
				Topbar.Visible = true

				if phase == "Starting" then
					queueNotification("GET READY", "Game starting soon!", NOTIFICATION_DURATION)
				elseif phase == "Planting" then
					queueNotification("PLANTING", "Plant bombs for the enemy to defuse", NOTIFICATION_DURATION)
				elseif phase == "Swapping" then
					queueNotification("SWAPPING", "Switching to enemy map", NOTIFICATION_DURATION)
				elseif phase == "Defusing" then
					queueNotification("DEFUSING", "Defuse all bombs before time runs out", NOTIFICATION_DURATION)
				elseif phase == "Intermission" then
					queueNotification("ROUND OVER", "Next round starting soon!", NOTIFICATION_DURATION)
				elseif phase == "GameOver" then
					local winner = scoreA > scoreB and "BLUE TEAM WINS" or scoreB > scoreA and "RED TEAM WINS" or "NO ONE WON"
					queueNotification(winner, "Next round starting soon!", NOTIFICATION_DURATION)
				end
			end
		end

	elseif action == "Team" then
		updateTeamAvatars(data.teamA, data.teamB)

	elseif action == "Credits" then
		CreditCount.Text = "Credits: " .. tostring(data)

	elseif action == "BombCount" then
		BombsLeftText.Text = "Bombs left: " .. (data.max - data.placed) .. "/" .. data.max

	elseif action == "Queue" then
		local status = data.status

		if status == "joined" then
			inQueue = true
			PlayButtonLabel.Text = "Leave"
			queuePrimaryNotification("QUEUEING", "Finding an opponent (0:00)")
			startQueueTimer()

		elseif status == "left" then
			inQueue = false
			stopQueueTimer()
			PlayButtonLabel.Text = "Play"
			hidePrimaryNotification()

		elseif status == "found" then
			inQueue = false
			stopQueueTimer()
			PlayButtonLabel.Text = "Play"
			queuePrimaryNotification("MATCH FOUND!", "Starting in " .. (data.data or 10) .. " seconds")

		elseif status == "countdown" then
			PrimarySubtext.Text = "Starting in " .. data.data .. " seconds"

		elseif status == "started" then
			inQueue = false
			stopQueueTimer()
			PlayButton.Visible = false
			CreditCounter.Visible = false
			ShopButton.Visible = false
			TasksButton.Visible = false
			hidePrimaryNotification()

		elseif status == "ended" then
			inQueue = false
			stopQueueTimer()
			PlayButton.Visible = true
			CreditCounter.Visible = true
			ShopButton.Visible = true
			TasksButton.Visible = true
			PlayButtonLabel.Text = "Play"
		end

	elseif action == "TaskCompleted" then
		print("[Tasks] Completed:", data.name, "+", data.reward, "credits")

	elseif action == "MicroNotify" then
		showMicroNotification(data.message)
	end
end)

-- Handle notifications
ClientNotify.OnClientEvent:Connect(function(message)
	queueNotification(message, nil, NOTIFICATION_DURATION)
end)

-- Apply button animations
applyButtonAnimation(PlayButton, function()
	if inQueue then
		ServerRequest:FireServer("LeaveQueue")
	else
		ServerRequest:FireServer("JoinQueue")
	end
end)

applyButtonAnimation(ShopButton)
applyButtonAnimation(TasksButton)

-- Debug credits
local CreditsTest = GameUI:FindFirstChild("CreditsTest")
if CreditsTest then
	applyButtonAnimation(CreditsTest, function()
		ServerRequest:FireServer("AddCredits", 10)
	end)
end

-- Initialize
CreditCounter.Visible = true
CreditCount.Text = "Credits: 0"

print("[GameUI] Loaded")