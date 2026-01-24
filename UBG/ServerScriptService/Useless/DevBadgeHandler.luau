local Players = game:GetService("Players")
local BadgeService = game:GetService("BadgeService")

local playerIds = {10166694901, 5282690507} -- Replace with actual player IDs
local badgeId = 1049524295040797 -- Replace with your badge ID

Players.PlayerAdded:Connect(function(player)
	for _, id in ipairs(playerIds) do
		local playerInGame = Players:GetPlayerByUserId(id)

		if playerInGame then
			local success, err = BadgeService:AwardBadgeAsync(player.UserId, badgeId)
			if success then
				print("Badge awarded to " .. player.Name)
			else
				warn("Failed to award badge: " .. tostring(err))
			end
			break -- Exit loop after awarding the badge
		end
	end
end)
