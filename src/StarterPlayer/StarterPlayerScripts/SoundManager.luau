-- LocalScript in StarterPlayerScripts/SoundManager
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ClientUpdate = ReplicatedStorage:WaitForChild("ClientUpdate")

-- Sound IDs (replace with your own)
local SOUNDS = {
	ButtonClick = "rbxassetid://0",
	Success = "rbxassetid://138862117963679",
	Failure = "rbxassetid://82512510989546",
	Countdown = "rbxassetid://0",
	BombPlant = "rbxassetid://0",
	BombDefuse = "rbxassetid://0",
	BombExplode = "rbxassetid://104292424667328",
	RoundEnd = "rbxassetid://0"
}

-- Music playlists
local LOBBY_MUSIC = {
	"rbxassetid://72634393256382",
	"rbxassetid://136841541830801",
	"rbxassetid://95902161274921",
	"rbxassetid://73106265270700",
}

local GAME_MUSIC = {
	"rbxassetid://129405439700867",
	"rbxassetid://106482254522677",
	"rbxassetid://124147189180591"
}

-- Config
local FADE_TIME = 2

-- Volume (0-100)
local musicVolume = 25
local sfxVolume = 25

-- State
local currentMusic = nil
local currentPlaylist = nil
local lastSongIndex = nil
local musicThread = nil

-- Get volume normalized
local function getMusicVolumeNormalized()
	return musicVolume / 100
end

local function getSFXVolumeNormalized()
	return sfxVolume / 100
end

-- Pick random song (avoid repeating)
local function pickSong(playlist)
	if #playlist == 1 then
		return 1
	end
	local index
	repeat
		index = math.random(1, #playlist)
	until index ~= lastSongIndex
	lastSongIndex = index
	return index
end

-- Play sound effect (separate from music)
local function playSFX(name)
	local id = SOUNDS[name]
	if not id or id == "rbxassetid://0" then return end

	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = getSFXVolumeNormalized()
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

-- Stop music
local function stopMusic()
	if musicThread then
		task.cancel(musicThread)
		musicThread = nil
	end

	if currentMusic then
		local old = currentMusic
		currentMusic = nil
		local fadeOut = TweenService:Create(old, TweenInfo.new(FADE_TIME), {Volume = 0})
		fadeOut:Play()
		fadeOut.Completed:Connect(function()
			old:Destroy()
		end)
	end

	currentPlaylist = nil
	lastSongIndex = nil
end

-- Play next song from playlist
local function playNextSong()
	if not currentPlaylist or #currentPlaylist == 0 then return end

	local index = pickSong(currentPlaylist)
	local id = currentPlaylist[index]
	if id == "rbxassetid://0" then return end

	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Looped = false
	sound.Volume = 0 -- start at 0 for fade-in
	sound.Parent = SoundService
	sound:Play()

	-- Fade in
	local fadeIn = TweenService:Create(sound, TweenInfo.new(FADE_TIME), {Volume = getMusicVolumeNormalized()})
	fadeIn:Play()

	currentMusic = sound

	-- Wait for song to end, then play next
	musicThread = task.spawn(function()
		sound.Ended:Wait()
		if currentPlaylist and sound == currentMusic then
			playNextSong()
		end
	end)
end

-- Play music playlist
local function playMusic(playlist)
	if currentPlaylist == playlist then return end
	stopMusic()
	currentPlaylist = playlist
	lastSongIndex = nil
	playNextSong()
end

-- Update music volume
local function updateMusicVolume()
	if currentMusic then
		currentMusic.Volume = getMusicVolumeNormalized()
	end
end

-- Listen to game events
ClientUpdate.OnClientEvent:Connect(function(action, data)
	if action == "Round" then
		local phase = data.phase
		if phase == "Waiting" then
			playMusic(LOBBY_MUSIC)
		elseif phase == "Loadout" or phase == "Planting" or phase == "Swapping" or phase == "Defusing" or phase == "Intermission" then
			playMusic(GAME_MUSIC)
		elseif phase == "GameOver" then
			playSFX("RoundEnd")
			playMusic(LOBBY_MUSIC) -- Return to lobby music after game ends
		end
	elseif action == "Queue" then
		if data.status == "found" then
			playSFX("Success")
		elseif data.status == "countdown" then
			playSFX("Countdown")
		end
	elseif action == "BombPlaced" then
		playSFX("BombPlant")
	elseif action == "BombDefused" then
		playSFX("BombDefuse")
	elseif action == "BombExploded" then
		playSFX("BombExplode")
	elseif action == "PlaySound" then
		playSFX(data.sound)
	end
end)

-- Start lobby music immediately on player join
playMusic(LOBBY_MUSIC)

-- Expose for UI
_G.SoundManager = {
	Play = playSFX,

	SetMusicVolume = function(vol)
		musicVolume = math.clamp(vol, 0, 100)
		updateMusicVolume()
	end,

	GetMusicVolume = function()
		return musicVolume
	end,

	SetSFXVolume = function(vol)
		sfxVolume = math.clamp(vol, 0, 100)
	end,

	GetSFXVolume = function()
		return sfxVolume
	end
}

print("[SoundManager] Loaded")
