-- ServerScriptService
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")

local COLLISION_GROUP = "Players"

-- make a group that doesn't collide with itself
PhysicsService:RegisterCollisionGroup(COLLISION_GROUP)
PhysicsService:CollisionGroupSetCollidable(COLLISION_GROUP, COLLISION_GROUP, false)

local function setCollisionGroup(character)
	-- throw every part into the group
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = COLLISION_GROUP
		end
	end

	-- catch any accessories that load in late
	character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = COLLISION_GROUP
		end
	end)
end

local function onPlayerAdded(player)
	if player.Character then
		setCollisionGroup(player.Character)
	end

	player.CharacterAdded:Connect(setCollisionGroup)
end

Players.PlayerAdded:Connect(onPlayerAdded)

-- in case any players snuck in before this ran
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end