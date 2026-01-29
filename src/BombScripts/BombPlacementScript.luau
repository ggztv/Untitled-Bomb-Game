local tool = script.Parent
local player = game.Players.LocalPlayer
local mouse = player:GetMouse()
local remote = game.ReplicatedStorage:WaitForChild("ServerRequest")
local clickSound = tool:FindFirstChild("Click")

tool.Activated:Connect(function()
	if not player.Character then return end

	local target = mouse.Target
	local hitPos = mouse.Hit.Position
	local hitNormal = Vector3.new(0, 1, 0)

	-- Raycast to get surface normal
	local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
	if rootPart and target then
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

	if clickSound then
		clickSound:Play()
	end

	remote:FireServer("PlaceBomb", {
		targetPosition = hitPos,
		targetNormal = hitNormal
	})
end)
