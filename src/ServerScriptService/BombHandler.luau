-- Script in ServerScriptService called "BombHandler"
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

-- Animation config
local PLACE_ANIM_TIME = 0.15
local DEFUSE_ANIM_TIME = 0.12

-- Wait for NetworkManager
repeat task.wait() until _G.NetworkManager
local NetworkManager = _G.NetworkManager

-- Wait for TaskManager
local TaskManager = nil
task.spawn(function()
	repeat task.wait() until _G.TaskManager
	TaskManager = _G.TaskManager
	print("[BombHandler] TaskManager connected")
end)

-- Config
local BOMBS_PER_PLAYER = 3
local DEFUSE_TIME = 7
local EXPLOSION_RADIUS = 25
local EXPLOSION_DAMAGE = 200 -- Instant kill (most humanoids have 100 HP)
local BOMB_PLACE_RANGE = 12
local FUSE_SOUND_RANGE = 150
local FUSE_SOUND_VOLUME = 0.3
local BOMB_SIZE = 2
local PLACEMENT_COOLDOWN = 0.5

-- Anti-cheat config
local DECOY_COUNT = 3
local USE_DECOYS = true
local MAX_DEFUSE_DISTANCE = 20

-- State
local bombs = {}
local bombOwners = {}
local teamABombs = {}
local teamBBombs = {}
local teamA = {}
local teamB = {}
local currentPhase = "None"
local defusingEnabled = false
local allBombsPlantedCallback = nil
local initialBombCountA = 0
local initialBombCountB = 0
local mapAFolder = nil
local mapBFolder = nil
local placementCooldowns = {}
local matchPlayers = {} -- Players in current match (for targeted broadcasts)

-- Anti-cheat state
local realBombRegistry = {}
local createdFolders = {}
local decoys = {}

-- Sound references
local bombTemplate = ServerStorage:WaitForChild("Bomb")
local fuseSound = bombTemplate:FindFirstChild("Fuse")
local explodeSound = bombTemplate:FindFirstChild("Explode")

-- Animation helper: scale bomb visually (uses mesh scale to keep hitbox unchanged)
local function animateBombScale(bomb, fromScale, toScale, duration, callback)
	-- Use Back easing for scale up (pop effect), Quad for scale down (smooth shrink)
	local easingStyle = fromScale < toScale and Enum.EasingStyle.Back or Enum.EasingStyle.Quad
	local easingDir = fromScale < toScale and Enum.EasingDirection.Out or Enum.EasingDirection.In
	local tweenInfo = TweenInfo.new(duration, easingStyle, easingDir)
	local tweens = {}

	local function getPartsWithMeshes(instance)
		local parts = {}
		if instance:IsA("BasePart") then
			local mesh = instance:FindFirstChildWhichIsA("DataModelMesh")
			if mesh then
				table.insert(parts, {part = instance, mesh = mesh})
			end
		end
		for _, child in instance:GetDescendants() do
			if child:IsA("BasePart") then
				local mesh = child:FindFirstChildWhichIsA("DataModelMesh")
				if mesh then
					table.insert(parts, {part = child, mesh = mesh})
				end
			end
		end
		return parts
	end

	local partsWithMeshes = getPartsWithMeshes(bomb)

	-- If no meshes found, use transparency animation as fallback
	if #partsWithMeshes == 0 then
		local parts = {}
		if bomb:IsA("BasePart") then
			table.insert(parts, bomb)
		end
		for _, child in bomb:GetDescendants() do
			if child:IsA("BasePart") then
				table.insert(parts, child)
			end
		end

		for _, part in parts do
			local fromTrans = fromScale < toScale and 1 or 0
			local toTrans = fromScale < toScale and 0 or 1
			part.Transparency = fromTrans
			local tween = TweenService:Create(part, TweenInfo.new(duration, Enum.EasingStyle.Quad), {Transparency = toTrans})
			table.insert(tweens, tween)
			tween:Play()
		end
	else
		-- Animate mesh scale (visual only, hitbox unchanged)
		for _, data in partsWithMeshes do
			local originalScale = data.mesh.Scale
			data.mesh.Scale = originalScale * fromScale
			local tween = TweenService:Create(data.mesh, tweenInfo, {Scale = originalScale * toScale})
			table.insert(tweens, tween)
			tween:Play()
		end
	end

	-- Always wait for animation to complete before callback
	if callback then
		if #tweens > 0 then
			tweens[1].Completed:Wait()
			callback()
		else
			task.wait(duration)
			callback()
		end
	end

	return tweens
end

-- Generate random name with random length
local function generateRandomName()
	local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"
	local length = math.random(5, 12)
	local name = ""
	for i = 1, length do
		local idx = math.random(1, #chars)
		name = name .. chars:sub(idx, idx)
	end
	return name
end

-- Get all valid parent locations in workspace
local function getValidParentLocations()
	local locations = {workspace}

	for _, child in workspace:GetDescendants() do
		if child:IsA("Model") or child:IsA("Folder") then
			local isValid = true
			for _, player in Players:GetPlayers() do
				if player.Character and child:IsDescendantOf(player.Character) then
					isValid = false
					break
				end
			end
			if child:IsDescendantOf(workspace.CurrentCamera) then
				isValid = false
			end
			if isValid then
				table.insert(locations, child)
			end
		end
	end

	return locations
end

-- Get random parent location
local function getRandomParentLocation()
	local locations = getValidParentLocations()
	return locations[math.random(1, #locations)]
end

-- Create a hidden folder at random location
local function createHiddenFolder()
	local folder = Instance.new("Folder")
	folder.Name = generateRandomName()
	folder.Parent = getRandomParentLocation()
	table.insert(createdFolders, folder)
	return folder
end

-- Get random folder (creates new ones scattered around)
local function getRandomFolder()
	if #createdFolders < 8 or math.random() > 0.5 then
		return createHiddenFolder()
	else
		return createdFolders[math.random(1, #createdFolders)]
	end
end

-- Get random position inside map
local function getRandomPositionInMap(mapFolder)
	if not mapFolder then return Vector3.new(0, 50, 0) end

	local minX, minY, minZ = math.huge, math.huge, math.huge
	local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge

	for _, part in mapFolder:GetDescendants() do
		if part:IsA("BasePart") then
			local pos = part.Position
			local size = part.Size / 2
			minX = math.min(minX, pos.X - size.X)
			minY = math.min(minY, pos.Y - size.Y)
			minZ = math.min(minZ, pos.Z - size.Z)
			maxX = math.max(maxX, pos.X + size.X)
			maxY = math.max(maxY, pos.Y + size.Y)
			maxZ = math.max(maxZ, pos.Z + size.Z)
		end
	end

	local x = math.random(math.floor(minX), math.floor(maxX))
	local y = math.random(math.floor(minY), math.floor(maxY))
	local z = math.random(math.floor(minZ), math.floor(maxZ))

	return Vector3.new(x, y, z)
end

-- Create decoy (clone actual bomb model)
local function createDecoy(mapFolder)
	local vpfBomb = ReplicatedStorage:WaitForChild("VPF"):FindFirstChild("Bomb")
	if not vpfBomb then return nil end

	local decoy = vpfBomb:Clone()
	decoy.Name = generateRandomName()

	local position = getRandomPositionInMap(mapFolder)

	if decoy:IsA("BasePart") then
		decoy.Anchored = true
		decoy.CanCollide = false
		decoy.Transparency = 1
		decoy.Position = position
	elseif decoy:IsA("Model") then
		for _, part in decoy:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
				part.Transparency = 1
			end
		end
		decoy:PivotTo(CFrame.new(position))
	end

	decoy.Parent = getRandomParentLocation()
	decoy:SetAttribute(generateRandomName(), math.random(1, 9999))

	table.insert(decoys, decoy)
	return decoy
end

-- Check if part is real bomb
local function isRealBomb(part)
	return realBombRegistry[part] ~= nil
end

-- Validate defuse attempt
local function validateDefuse(player, part)
	if not isRealBomb(part) then
		warn("[BombHandler] Fake bomb defuse attempt:", player.Name)
		return false
	end

	local character = player.Character
	if not character then return false end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return false end

	local bombPos
	if part:IsA("Model") then
		local primary = part.PrimaryPart or part:FindFirstChildWhichIsA("BasePart")
		bombPos = primary and primary.Position or Vector3.new(0, 0, 0)
	else
		bombPos = part.Position
	end

	local distance = (rootPart.Position - bombPos).Magnitude
	if distance > MAX_DEFUSE_DISTANCE then
		warn("[BombHandler] Too far to defuse:", player.Name, distance)
		return false
	end

	return true
end

-- Check if player has fuse cutter equipped
local function hasFuseCutterEquipped(player)
	local character = player.Character
	if not character then return false end

	local equippedTool = character:FindFirstChildWhichIsA("Tool")
	return equippedTool and equippedTool.Name == "Fuse Cutter"
end

-- Get player team
local function getPlayerTeam(player)
	if table.find(teamA, player) then
		return "A"
	elseif table.find(teamB, player) then
		return "B"
	end
	return nil
end

-- Get the enemy map folder for bomb placement
local function getEnemyMapFolder(player)
	local team = getPlayerTeam(player)
	if not team then 
		return nil 
	end

	if team == "A" then
		return mapBFolder
	else
		return mapAFolder
	end
end

-- Count bombs placed by player
local function countPlayerBombs(player)
	local count = 0
	for bomb, owner in bombOwners do
		if owner == player and bomb and bomb.Parent then
			count += 1
		end
	end
	return count
end

-- Update bomb count for player
local function updateBombCount(player)
	local placed = countPlayerBombs(player)
	NetworkManager.SendToClient(player, "BombCount", {
		placed = placed,
		max = BOMBS_PER_PLAYER,
		phase = currentPhase
	})
end

-- Check if all bombs are planted
local function checkAllBombsPlanted()
	local teamAPlaced = 0
	local teamBPlaced = 0

	for bomb, owner in bombOwners do
		if bomb and bomb.Parent then
			if table.find(teamA, owner) then
				teamAPlaced += 1
			elseif table.find(teamB, owner) then
				teamBPlaced += 1
			end
		end
	end

	local teamAMax = #teamA * BOMBS_PER_PLAYER
	local teamBMax = #teamB * BOMBS_PER_PLAYER

	if teamAPlaced >= teamAMax and teamBPlaced >= teamBMax then
		if allBombsPlantedCallback then
			allBombsPlantedCallback()
		end
	end
end

-- Create explosion effect
local function createExplosion(position)
	local explosion = Instance.new("Explosion")
	explosion.Position = position
	explosion.BlastRadius = EXPLOSION_RADIUS
	explosion.BlastPressure = 500 -- Add some knockback
	explosion.DestroyJointRadiusPercent = 0 -- Don't break joints, we handle damage manually

	-- Track which characters we've already damaged to prevent double-hits
	local damagedCharacters = {}

	explosion.Hit:Connect(function(part, distance)
		local character = part:FindFirstAncestorOfClass("Model")
		if not character then return end
		if damagedCharacters[character] then return end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end

		-- Mark as damaged
		damagedCharacters[character] = true

		-- Calculate damage based on distance (full damage at center, less at edges)
		local damageMultiplier = 1 - (distance / EXPLOSION_RADIUS)
		local damage = EXPLOSION_DAMAGE * math.max(damageMultiplier, 0.5) -- Min 50% damage

		humanoid:TakeDamage(damage)
	end)

	explosion.Parent = workspace

	-- Only notify players in the current match
	NetworkManager.SendToPlayers(matchPlayers, "BombExploded", {position = position})
end

-- Add fuse sound to bomb
local function addFuseSound(mainPart)
	if not fuseSound or not mainPart then return nil end

	local sound = fuseSound:Clone()
	sound.Looped = true
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 5
	sound.RollOffMaxDistance = FUSE_SOUND_RANGE
	sound.Volume = FUSE_SOUND_VOLUME
	sound.Parent = mainPart
	sound:Play()

	return sound
end

-- Anchor bomb after it settles (optimized for faster response)
local function anchorBombAfterSettle(bomb)
	task.spawn(function()
		local mainPart = bomb
		if bomb:IsA("Model") then
			mainPart = bomb.PrimaryPart or bomb:FindFirstChildWhichIsA("BasePart")
		end
		if not mainPart then return end

		local startTime = tick()
		local maxWaitTime = 1.5 -- Reduced from 3

		while tick() - startTime < maxWaitTime do
			task.wait(0.05) -- Faster polling
			if not bomb or not bomb.Parent then return end

			local velocity = mainPart.AssemblyLinearVelocity
			if velocity.Magnitude < 0.5 then
				task.wait(0.05)
				break
			end
		end

		if bomb and bomb.Parent then
			if bomb:IsA("BasePart") then
				bomb.Anchored = true
			elseif bomb:IsA("Model") then
				for _, part in bomb:GetDescendants() do
					if part:IsA("BasePart") then
						part.Anchored = true
					end
				end
			end
		end
	end)
end

-- Create bomb at position
local function createBomb(position, owner, mapFolder)
	local vpfBomb = ReplicatedStorage:WaitForChild("VPF"):FindFirstChild("Bomb")
	local bomb

	if vpfBomb then
		bomb = vpfBomb:Clone()
		bomb.Name = generateRandomName()

		if bomb:IsA("BasePart") then
			bomb.Position = position
			bomb.Anchored = false
			bomb.CanCollide = true
		elseif bomb:IsA("Model") then
			bomb:PivotTo(CFrame.new(position))
			for _, part in bomb:GetDescendants() do
				if part:IsA("BasePart") then
					part.Anchored = false
					part.CanCollide = true
				end
			end
		end
	else
		bomb = Instance.new("Part")
		bomb.Name = generateRandomName()
		bomb.Size = Vector3.new(2, 2, 2)
		bomb.Position = position
		bomb.Anchored = false
		bomb.CanCollide = true
		bomb.Material = Enum.Material.Metal
		bomb.BrickColor = BrickColor.new("Really black")

		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = bomb
	end

	bomb.Parent = getRandomFolder()

	realBombRegistry[bomb] = {
		owner = owner,
		map = mapFolder,
		defused = false,
		team = getPlayerTeam(owner)
	}

	if USE_DECOYS then
		for i = 1, DECOY_COUNT do
			createDecoy(mapFolder)
		end
	end

	local mainPart = bomb
	if bomb:IsA("Model") then
		mainPart = bomb.PrimaryPart or bomb:FindFirstChildWhichIsA("BasePart")
	end

	if mainPart then
		addFuseSound(mainPart)
	end

	if mainPart then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = generateRandomName()
		prompt.ActionText = "Defuse"
		prompt.ObjectText = "Bomb"
		prompt.HoldDuration = DEFUSE_TIME
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = true
		prompt.Enabled = false
		prompt.Parent = mainPart

		prompt.PromptButtonHoldBegan:Connect(function(player)
			if not defusingEnabled then return end

			if not hasFuseCutterEquipped(player) then
				NetworkManager.Notify(player, "Equip Fuse Cutter to defuse!")
				prompt.Enabled = false
				task.wait(0.1)
				prompt.Enabled = true
			end
		end)

		prompt.Triggered:Connect(function(player)
			-- Immediately disable prompt to prevent delay
			prompt.Enabled = false

			if not defusingEnabled then return end

			if not hasFuseCutterEquipped(player) then
				prompt.Enabled = true
				return
			end

			if not validateDefuse(player, bomb) then
				prompt.Enabled = true
				return
			end

			local bombData = realBombRegistry[bomb]
			if not bombData or bombData.defused then return end

			bombData.defused = true

			local team = bombData.team
			if team == "A" then
				local index = table.find(teamABombs, bomb)
				if index then table.remove(teamABombs, index) end
			elseif team == "B" then
				local index = table.find(teamBBombs, bomb)
				if index then table.remove(teamBBombs, index) end
			end

			local bombIndex = table.find(bombs, bomb)
			if bombIndex then table.remove(bombs, bombIndex) end

			if TaskManager then
				TaskManager.RecordBombDefused(player)
			end

			-- Stop fuse sound immediately
			for _, s in mainPart:GetChildren() do
				if s:IsA("Sound") and s.Looped then
					s:Stop()
				end
			end

			-- Only notify players in the current match
			NetworkManager.SendToPlayers(matchPlayers, "BombDefused", {position = mainPart.Position})

			-- Animate scale down then destroy (non-blocking)
			task.spawn(function()
				animateBombScale(bomb, 1, 0, DEFUSE_ANIM_TIME, function()
					if bomb and bomb.Parent then
						bomb:Destroy()
					end
				end)
			end)

			print("[BombHandler]", player.Name, "defused a bomb")
		end)
	end

	table.insert(bombs, bomb)
	bombOwners[bomb] = owner

	local team = getPlayerTeam(owner)
	if team == "A" then
		table.insert(teamABombs, bomb)
	elseif team == "B" then
		table.insert(teamBBombs, bomb)
	end

	-- Animate scale up on placement
	animateBombScale(bomb, 0, 1, PLACE_ANIM_TIME)

	anchorBombAfterSettle(bomb)

	return bomb
end

-- Explode bomb
local function explodeBomb(bomb)
	if not bomb or not bomb.Parent then return end

	local mainPart = bomb
	if bomb:IsA("Model") then
		mainPart = bomb.PrimaryPart or bomb:FindFirstChildWhichIsA("BasePart")
	end

	local position = mainPart and mainPart.Position or Vector3.new(0, 0, 0)

	if mainPart then
		for _, s in mainPart:GetChildren() do
			if s:IsA("Sound") and s.Looped then
				s:Stop()
				s:Destroy()
			end
		end
	end

	if explodeSound then
		local soundPart = Instance.new("Part")
		soundPart.Anchored = true
		soundPart.CanCollide = false
		soundPart.Transparency = 1
		soundPart.Size = Vector3.new(1, 1, 1)
		soundPart.Position = position
		soundPart.Parent = workspace

		local sound = explodeSound:Clone()
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = 10
		sound.RollOffMaxDistance = 200
		sound.Parent = soundPart
		sound:Play()

		Debris:AddItem(soundPart, sound.TimeLength + 1)
	end

	realBombRegistry[bomb] = nil
	bombOwners[bomb] = nil

	local index = table.find(bombs, bomb)
	if index then table.remove(bombs, index) end

	local indexA = table.find(teamABombs, bomb)
	if indexA then table.remove(teamABombs, indexA) end

	local indexB = table.find(teamBBombs, bomb)
	if indexB then table.remove(teamBBombs, indexB) end

	bomb:Destroy()
	createExplosion(position)
end

-- Get bomb position helper
local function getBombPosition(bomb)
	if not bomb then return nil end
	if bomb:IsA("Model") then
		local primary = bomb.PrimaryPart or bomb:FindFirstChildWhichIsA("BasePart")
		return primary and primary.Position
	else
		return bomb.Position
	end
end

-- Place bomb at position (called from network handler)
local function placeBombAtPosition(player, targetPosition, targetNormal)
	if currentPhase ~= "Planting" then return false end

	-- Check cooldown
	local now = tick()
	if placementCooldowns[player] and now - placementCooldowns[player] < PLACEMENT_COOLDOWN then
		return false
	end
	placementCooldowns[player] = now

	local character = player.Character
	if not character then return false end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return false end

	local distance = (rootPart.Position - targetPosition).Magnitude
	if distance > BOMB_PLACE_RANGE + 5 then
		NetworkManager.SendToClient(player, "PlaySound", {sound = "Failure"})
		return false
	end

	local placed = countPlayerBombs(player)
	if placed >= BOMBS_PER_PLAYER then
		NetworkManager.Notify(player, "No bombs left!")
		NetworkManager.SendToClient(player, "PlaySound", {sound = "Failure"})
		return false
	end

	local mapFolder = getEnemyMapFolder(player)
	if not mapFolder then
		NetworkManager.Notify(player, "Not on enemy map!")
		NetworkManager.SendToClient(player, "PlaySound", {sound = "Failure"})
		return false
	end

	if not character:FindFirstChild("Bomb") then
		NetworkManager.SendToClient(player, "PlaySound", {sound = "Failure"})
		return false
	end

	-- Calculate spawn position offset by surface normal
	local normal = targetNormal or Vector3.new(0, 1, 0)
	local spawnPos = targetPosition + normal * BOMB_SIZE

	-- Additional check: if placing on a mostly vertical surface, add upward offset so it falls
	if math.abs(normal.Y) < 0.5 then
		spawnPos = spawnPos + Vector3.new(0, BOMB_SIZE, 0)
	end

	-- Check for existing bombs at this location
	for existingBomb, _ in bombOwners do
		if existingBomb and existingBomb.Parent then
			local existingPos = getBombPosition(existingBomb)
			if existingPos and (existingPos - spawnPos).Magnitude < BOMB_SIZE * 2 then
				NetworkManager.Notify(player, "Too close to another bomb!")
				NetworkManager.SendToClient(player, "PlaySound", {sound = "Failure"})
				return false
			end
		end
	end

	local bomb = createBomb(spawnPos, player, mapFolder)

	if TaskManager then
		TaskManager.RecordBombPlanted(player)
	end

	local bombPos = getBombPosition(bomb) or spawnPos

	-- Only notify players in the current match
	NetworkManager.SendToPlayers(matchPlayers, "BombPlaced", {position = bombPos})
	updateBombCount(player)
	checkAllBombsPlanted()

	print("[BombHandler]", player.Name, "planted a bomb. Total:", placed + 1, "/", BOMBS_PER_PLAYER)
	return true
end

-- Give bomb tool to player
local function giveBombTool(player)
	local tool = bombTemplate:Clone()

	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		tool.Parent = backpack
	end

	return tool
end

-- Give fuse cutter tool to player
local function giveFuseCutterTool(player)
	local fuseCutterTemplate = ServerStorage:WaitForChild("Fuse Cutter")
	local tool = fuseCutterTemplate:Clone()
	tool:SetAttribute("Enabled", false)

	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		tool.Parent = backpack
	end

	return tool
end

-- Public functions
_G.BombHandler = {}

_G.BombHandler.SetMaps = function(mapA, mapB)
	mapAFolder = mapA
	mapBFolder = mapB
	print("[BombHandler] Maps set - A:", mapA and mapA.Name, "B:", mapB and mapB.Name)
end

_G.BombHandler.SetTeams = function(tA, tB)
	teamA = tA or {}
	teamB = tB or {}
end

_G.BombHandler.SetMatchPlayers = function(players)
	matchPlayers = players or {}
end

_G.BombHandler.SetPhase = function(phase)
	currentPhase = phase
	print("[BombHandler] Phase:", phase)
end

_G.BombHandler.GetPhase = function()
	return currentPhase
end

_G.BombHandler.SetAllBombsPlantedCallback = function(callback)
	allBombsPlantedCallback = callback
end

_G.BombHandler.GiveBombs = function()
	for _, player in teamA do
		if player and player.Parent then
			giveBombTool(player)
			giveFuseCutterTool(player)
			updateBombCount(player)
		end
	end

	for _, player in teamB do
		if player and player.Parent then
			giveBombTool(player)
			giveFuseCutterTool(player)
			updateBombCount(player)
		end
	end
end

_G.BombHandler.RemoveBombTools = function()
	print("[BombHandler] RemoveBombTools called")
	for _, player in Players:GetPlayers() do
		local backpack = player:FindFirstChild("Backpack")
		local character = player.Character

		if backpack then
			local tool = backpack:FindFirstChild("Bomb")
			if tool then 
				print("[BombHandler] Destroying Bomb from", player.Name, "backpack")
				tool:Destroy() 
			end
		end

		if character then
			local tool = character:FindFirstChild("Bomb")
			if tool then 
				print("[BombHandler] Destroying Bomb from", player.Name, "character")
				tool:Destroy() 
			end
		end
	end

	task.wait(0.1)
	print("[BombHandler] === AFTER REMOVAL ===")
	for _, player in Players:GetPlayers() do
		local backpack = player:FindFirstChild("Backpack")
		local character = player.Character
		print("[BombHandler]", player.Name, "tools:")
		if backpack then
			for _, c in backpack:GetChildren() do
				if c:IsA("Tool") then print("  Backpack:", c.Name) end
			end
		end
		if character then
			for _, c in character:GetChildren() do
				if c:IsA("Tool") then print("  Character:", c.Name) end
			end
		end
	end
end

_G.BombHandler.EnableDefusing = function()
	defusingEnabled = true
	initialBombCountA = #teamABombs
	initialBombCountB = #teamBBombs

	for _, bomb in bombs do
		if bomb and bomb.Parent then
			local mainPart = bomb
			if bomb:IsA("Model") then
				mainPart = bomb.PrimaryPart or bomb:FindFirstChildWhichIsA("BasePart")
			end
			if mainPart then
				local prompt = mainPart:FindFirstChildWhichIsA("ProximityPrompt")
				if prompt then prompt.Enabled = true end
			end
		end
	end

	print("[BombHandler] Defusing enabled. Bombs - A:", initialBombCountA, "B:", initialBombCountB)
end

_G.BombHandler.DisableDefusing = function()
	defusingEnabled = false

	for _, bomb in bombs do
		if bomb and bomb.Parent then
			local mainPart = bomb
			if bomb:IsA("Model") then
				mainPart = bomb.PrimaryPart or bomb:FindFirstChildWhichIsA("BasePart")
			end
			if mainPart then
				local prompt = mainPart:FindFirstChildWhichIsA("ProximityPrompt")
				if prompt then prompt.Enabled = false end
			end
		end
	end
end

_G.BombHandler.AllDefusedOnMapA = function()
	return #teamABombs == 0
end

_G.BombHandler.AllDefusedOnMapB = function()
	return #teamBBombs == 0
end

_G.BombHandler.GetRemainingOnMapA = function()
	return #teamABombs
end

_G.BombHandler.GetRemainingOnMapB = function()
	return #teamBBombs
end

_G.BombHandler.GetInitialBombCounts = function()
	return initialBombCountA, initialBombCountB
end

_G.BombHandler.ExplodeMapA = function()
	for _, bomb in teamABombs do
		if bomb and bomb.Parent then
			explodeBomb(bomb)
		end
	end
	teamABombs = {}
end

_G.BombHandler.ExplodeMapB = function()
	for _, bomb in teamBBombs do
		if bomb and bomb.Parent then
			explodeBomb(bomb)
		end
	end
	teamBBombs = {}
end

_G.BombHandler.Reset = function()
	for _, bomb in bombs do
		if bomb and bomb.Parent then
			bomb:Destroy()
		end
	end
	bombs = {}
	bombOwners = {}
	teamABombs = {}
	teamBBombs = {}

	realBombRegistry = {}
	placementCooldowns = {}

	for _, decoy in decoys do
		if decoy and decoy.Parent then
			decoy:Destroy()
		end
	end
	decoys = {}

	for _, folder in createdFolders do
		if folder and folder.Parent then
			folder:Destroy()
		end
	end
	createdFolders = {}

	defusingEnabled = false
	allBombsPlantedCallback = nil
	initialBombCountA = 0
	initialBombCountB = 0
	currentPhase = "None"
	mapAFolder = nil
	mapBFolder = nil
	matchPlayers = {}

	for _, player in Players:GetPlayers() do
		local backpack = player:FindFirstChild("Backpack")
		local character = player.Character

		if backpack then
			local bomb = backpack:FindFirstChild("Bomb")
			local cutter = backpack:FindFirstChild("Fuse Cutter")
			if bomb then bomb:Destroy() end
			if cutter then cutter:Destroy() end
		end

		if character then
			local bomb = character:FindFirstChild("Bomb")
			local cutter = character:FindFirstChild("Fuse Cutter")
			if bomb then bomb:Destroy() end
			if cutter then cutter:Destroy() end
		end
	end

	print("[BombHandler] Reset complete")
end

print("[BombHandler] Loaded")

-- Register network handler for bomb placement
NetworkManager.RegisterHandler("PlaceBomb", function(player, data)
	if not data or not data.targetPosition then return end
	placeBombAtPosition(player, data.targetPosition, data.targetNormal)
end)