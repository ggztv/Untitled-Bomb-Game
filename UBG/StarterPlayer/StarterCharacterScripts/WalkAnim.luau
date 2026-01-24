local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local char = script.Parent
local humanoid = char:WaitForChild("Humanoid")
local rootPart = char:WaitForChild("HumanoidRootPart")
local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
local camera = workspace.CurrentCamera

-- Config
local BASE_FOV = camera.FieldOfView
local RUN_FOV = BASE_FOV + 5
local JUMP_FOV = BASE_FOV + 8
local BASE_SPEED, SPRINT_SPEED = humanoid.WalkSpeed, 20
local FOOTSTEP_SOUND, FOOTSTEP_VOLUME = "rbxassetid://128342262001262", 0.5
local WALK_KEYFRAMES, RUN_KEYFRAMES = {0.1, 0.57}, {0.1, 0.45}
local ANIM_FADE_TIME = 0.15

-- Animations
local walkAnim, runAnim = Instance.new("Animation"), Instance.new("Animation")
walkAnim.AnimationId, runAnim.AnimationId = "rbxassetid://107065933779417", "rbxassetid://126122298976460"
ContentProvider:PreloadAsync({walkAnim, runAnim})

local walkTrack, runTrack = animator:LoadAnimation(walkAnim), animator:LoadAnimation(runAnim)
walkTrack.Looped, runTrack.Looped = true, true
walkTrack.Priority, runTrack.Priority = Enum.AnimationPriority.Movement, Enum.AnimationPriority.Movement

-- States
local BLOCKED_STATES = {Climbing=true, Jumping=true, Freefall=true, FallingDown=true, Swimming=true, Seated=true}
local AIRBORNE_STATES = {Jumping=true, Freefall=true, FallingDown=true}
local INSTANT_STOP_STATES = {Climbing=true, Swimming=true, Seated=true}
local sprinting, animationLocked, fovTween = false, false, nil
local walkIndex, runIndex, lastWalkPos, lastRunPos = 1, 1, 0, 0
local isAirborne = false

-- Sound pool
local soundPool, poolIndex = {}, 1
for i = 1, 3 do
	local s = Instance.new("Sound")
	s.SoundId, s.Volume, s.Parent = FOOTSTEP_SOUND, FOOTSTEP_VOLUME, rootPart
	soundPool[i] = s
end

-- Disable default footsteps
local function removeRunningSound(parent)
	local sound = parent:FindFirstChild("Running")
	if sound then sound:Destroy() end
end
removeRunningSound(rootPart)
rootPart.ChildAdded:Connect(function(child)
	if child.Name == "Running" and child:IsA("Sound") then child:Destroy() end
end)

-- Shift lock
task.spawn(function()
	Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")
		:WaitForChild("CameraModule"):WaitForChild("MouseLockController")
		:WaitForChild("BoundKeys").Value = "LeftControl"
end)

-- Helpers
local function playFootstep()
	soundPool[poolIndex]:Play()
	poolIndex = poolIndex % 3 + 1
end

local function stopAnimations(fade)
	local fadeTime = fade and ANIM_FADE_TIME or 0
	if walkTrack.IsPlaying then walkTrack:Stop(fadeTime) end
	if runTrack.IsPlaying then runTrack:Stop(fadeTime) end
end

local function setFOV(v)
	if fovTween then fovTween:Cancel() end
	fovTween = TweenService:Create(camera, TweenInfo.new(0.15), {FieldOfView = v})
	fovTween:Play()
end

local function getTargetFOV()
	if isAirborne then
		return JUMP_FOV
	elseif sprinting then
		return RUN_FOV
	else
		return BASE_FOV
	end
end

local function update(speed)
	if animationLocked or speed <= 0.1 then stopAnimations(true) return end

	if sprinting then
		if walkTrack.IsPlaying then walkTrack:Stop(ANIM_FADE_TIME) end
		if not runTrack.IsPlaying then runTrack:Play(ANIM_FADE_TIME); runIndex, lastRunPos = 1, 0 end
	else
		if runTrack.IsPlaying then runTrack:Stop(ANIM_FADE_TIME) end
		if not walkTrack.IsPlaying then walkTrack:Play(ANIM_FADE_TIME); walkIndex, lastWalkPos = 1, 0 end
	end
end

-- Events
humanoid.StateChanged:Connect(function(_, newState)
	local stateName = newState.Name
	animationLocked = BLOCKED_STATES[stateName] or false

	if animationLocked then
		local instant = INSTANT_STOP_STATES[stateName] or false
		stopAnimations(not instant)
	end

	-- Handle airborne FOV
	local wasAirborne = isAirborne
	isAirborne = AIRBORNE_STATES[stateName] or false

	if isAirborne ~= wasAirborne then
		setFOV(getTargetFOV())
	end
end)

humanoid.Running:Connect(function(speed)
	if animationLocked then stopAnimations(true) else update(speed) end
end)

UserInputService.InputBegan:Connect(function(i, gp)
	if gp or i.KeyCode ~= Enum.KeyCode.LeftShift then return end
	sprinting = true
	humanoid.WalkSpeed = SPRINT_SPEED
	setFOV(getTargetFOV())
end)

UserInputService.InputEnded:Connect(function(i, gp)
	if gp or i.KeyCode ~= Enum.KeyCode.LeftShift then return end
	sprinting = false
	humanoid.WalkSpeed = BASE_SPEED
	setFOV(getTargetFOV())
end)

RunService.Heartbeat:Connect(function()
	if animationLocked then return end

	if walkTrack.IsPlaying then
		local pos = walkTrack.TimePosition
		if pos < lastWalkPos then walkIndex = 1 end
		lastWalkPos = pos
		if walkIndex <= #WALK_KEYFRAMES and pos >= WALK_KEYFRAMES[walkIndex] then
			playFootstep()
			walkIndex += 1
		end
	end

	if runTrack.IsPlaying then
		local pos = runTrack.TimePosition
		if pos < lastRunPos then runIndex = 1 end
		lastRunPos = pos
		if runIndex <= #RUN_KEYFRAMES and pos >= RUN_KEYFRAMES[runIndex] then
			playFootstep()
			runIndex += 1
		end
	end
end)