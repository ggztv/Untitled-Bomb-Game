-- ServerScriptService/NameTagHandler
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local DataStoreService = game:GetService("DataStoreService")

local nametag = ReplicatedStorage:WaitForChild("NameTag")
local nameStore = DataStoreService:GetDataStore("PlayerDisplayNames")

local changeNameEvent = Instance.new("RemoteEvent")
changeNameEvent.Name = "ChangeName"
changeNameEvent.Parent = ReplicatedStorage

local playerNames = {}

local bannedWords = {
	"ggztv",
	"theggztv",
}

local exemptUserIds = {
	[9724571334] = true,
	[10166694901] = true,
}

local defaultTitles = {
	["theggztv"] = {text = "guy who made this game", color = Color3.fromRGB(255, 51, 0)},
	["nine"] = {text = "co-owner", color = Color3.fromRGB(255, 255, 255)}
}

local homoglyphs = {
	-- G lookalikes
	["ɡ"] = "g", ["ġ"] = "g", ["ğ"] = "g", ["ǧ"] = "g", ["ģ"] = "g", ["ǥ"] = "g", ["ɢ"] = "g", ["ԍ"] = "g", ["ᶃ"] = "g", ["ᵹ"] = "g",

	-- Z lookalikes
	["ᴢ"] = "z", ["ž"] = "z", ["ź"] = "z", ["ż"] = "z", ["ẑ"] = "z", ["ẓ"] = "z", ["ẕ"] = "z", ["ⱬ"] = "z", ["ᵶ"] = "z", ["ᶎ"] = "z", ["з"] = "z", ["З"] = "z",

	-- T lookalikes
	["т"] = "t", ["Т"] = "t", ["ţ"] = "t", ["ť"] = "t", ["ŧ"] = "t", ["ṫ"] = "t", ["ṭ"] = "t", ["ṯ"] = "t", ["ṱ"] = "t", ["ẗ"] = "t", ["ⱦ"] = "t", ["τ"] = "t", ["Τ"] = "t",

	-- V lookalikes
	["ν"] = "v", ["Ν"] = "v", ["ᴠ"] = "v", ["ṽ"] = "v", ["ṿ"] = "v", ["ⱱ"] = "v", ["ⱴ"] = "v", ["в"] = "v", ["В"] = "v",

	-- H lookalikes
	["һ"] = "h", ["Һ"] = "h", ["ĥ"] = "h", ["ħ"] = "h", ["ḣ"] = "h", ["ḥ"] = "h", ["ḧ"] = "h", ["ḩ"] = "h", ["ḫ"] = "h", ["ⱨ"] = "h", ["н"] = "h", ["Н"] = "h", ["η"] = "h",

	-- E lookalikes
	["е"] = "e", ["Е"] = "e", ["ė"] = "e", ["ę"] = "e", ["ě"] = "e", ["ĕ"] = "e", ["ē"] = "e", ["ẹ"] = "e", ["ẻ"] = "e", ["ẽ"] = "e", ["ế"] = "e", ["ề"] = "e", ["ể"] = "e", ["ễ"] = "e", ["ệ"] = "e", ["ε"] = "e", ["Ε"] = "e", ["ё"] = "e", ["Ё"] = "e",
}

local function normalizeForCheck(text)
	local result = ""
	for _, codepoint in utf8.codes(text) do
		local char = utf8.char(codepoint)
		result = result .. (homoglyphs[char] or char)
	end
	return result:lower():gsub("%s+", "")
end

local function containsBannedWord(text)
	local normalized = normalizeForCheck(text)
	for _, word in bannedWords do
		if normalized:find(word, 1, true) then
			return true
		end
	end
	return false
end

local function isExempt(player)
	return exemptUserIds[player.UserId]
end

local function filterText(text, playerId)
	local success, result = pcall(function()
		local filtered = TextService:FilterStringAsync(text, playerId)
		return filtered:GetNonChatStringForBroadcastAsync()
	end)
	if success then
		return result
	else
		return nil
	end
end

local function loadPlayerName(player)
	local success, result = pcall(function()
		return nameStore:GetAsync("user_" .. player.UserId)
	end)
	if success and result then
		playerNames[player.UserId] = result
		return result
	end
	return nil
end

local function savePlayerName(player)
	local name = playerNames[player.UserId]
	if name then
		pcall(function()
			nameStore:SetAsync("user_" .. player.UserId, name)
		end)
	end
end

local function setupNametag(player, char)
	local head = char:WaitForChild("Head", 10)
	local humanoid = char:WaitForChild("Humanoid", 10)

	if not head or not humanoid then return end

	local existingTag = head:FindFirstChild("NameTag")
	if existingTag then
		existingTag:Destroy()
	end

	local newtext = nametag:Clone()
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	newtext.Parent = head
	newtext.Adornee = head

	local saved = playerNames[player.UserId]
	newtext.UpperText.Text = saved or player.Name

	if defaultTitles[player.Name] then
		newtext.LowerText.Text = defaultTitles[player.Name].text
		newtext.LowerText.TextColor3 = defaultTitles[player.Name].color
	end
end

local function onPlayerAdded(player)
	loadPlayerName(player)

	if player.Character then
		setupNametag(player, player.Character)
	end

	player.CharacterAdded:Connect(function(char)
		task.wait()
		setupNametag(player, char)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

changeNameEvent.OnServerEvent:Connect(function(player, newName)
	if type(newName) ~= "string" then return end
	if #newName == 0 or #newName > 20 then return end

	if not isExempt(player) then
		if containsBannedWord(newName) then return end
	end

	local filtered = filterText(newName, player.UserId)
	if not filtered then return end

	if not isExempt(player) then
		if containsBannedWord(filtered) then return end
	end

	playerNames[player.UserId] = filtered

	local char = player.Character
	if char and char:FindFirstChild("Head") then
		local tag = char.Head:FindFirstChild("NameTag")
		if tag then
			tag.UpperText.Text = filtered
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	savePlayerName(player)
	playerNames[player.UserId] = nil
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		savePlayerName(player)
	end
end)