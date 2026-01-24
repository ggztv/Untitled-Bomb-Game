-- No Reset
local StarterGui = game:GetService("StarterGui")

-- Disable reset button
local function disableReset()
	local success
	repeat
		success = pcall(function()
			StarterGui:SetCore("ResetButtonCallback", false)
		end)
		if not success then task.wait() end
	until success
end

task.spawn(disableReset)


-- Sound Helper
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local function setListener()
	local character = player.Character
	if character then
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			SoundService:SetListener(Enum.ListenerType.ObjectPosition, rootPart)
		end
	end
end

player.CharacterAdded:Connect(setListener)
if player.Character then setListener() end