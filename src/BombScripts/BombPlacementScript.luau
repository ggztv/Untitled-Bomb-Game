local tool = script.Parent
local player = game.Players.LocalPlayer
local mouse = player:GetMouse()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remote = ReplicatedStorage:WaitForChild("ServerRequest")
local clientUpdate = ReplicatedStorage:WaitForChild("ClientUpdate")
local clickSound = tool:FindFirstChild("Click")

-- Client-side config (should match server)
local BOMB_PLACE_RANGE = 12

-- Play click sound on successful placement
clientUpdate.OnClientEvent:Connect(function(action, data)
	if action == "BombPlaced" and clickSound then
		clickSound:Play()
	end
end)

tool.Activated:Connect(function()
	if not player.Character then return end

	local target = mouse.Target
	local hitPos = mouse.Hit.Position
	local hitNormal = Vector3.new(0, 1, 0)

	local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	-- Raycast to get surface normal
	if target then
		local origin = rootPart.Position
		local direction = (hitPos - origin).Unit * 100

		local rayParams = RaycastParams.new()
		rayParams.FilterDescendantsInstances = {player.Character}
		rayParams.FilterType = Enum.RaycastFilterType.Exclude

		local result = workspace:Raycast(origin, direction, rayParams)
		if result then
			hitPos = result.Position
			hitNormal = result.Normal
		end
	end

	-- Client-side distance check for immediate feedback (no server round-trip)
	local distance = (rootPart.Position - hitPos).Magnitude
	if distance > BOMB_PLACE_RANGE + 5 then
		-- Show failure immediately - no need to wait for server
		if _G.ShowMicroNotification then
			_G.ShowMicroNotification("Too far away!")
		end
		return
	end

	-- Send to server for full validation
	remote:FireServer("PlaceBomb", {
		targetPosition = hitPos,
		targetNormal = hitNormal
	})
end)
