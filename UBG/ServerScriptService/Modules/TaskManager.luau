-- ModuleScript in ServerScriptService/Modules/TaskManager
local Players = game:GetService("Players")

local TaskManager = {}

local DataManager = nil
local NetworkManager = nil

-- Task definitions (balanced for 2+ games minimum)
local DAILY_TASKS = {
	{name = "Play 5 Games", goal = 5, stat = "gamesPlayed", reward = 1},
	{name = "Plant 30 Bombs", goal = 30, stat = "bombsPlanted", reward = 2},
	{name = "Win 2 Games", goal = 2, stat = "gamesWon", reward = 3}
}

local BONUS_TASKS = {
	{name = "Play 12 Games", goal = 12, stat = "gamesPlayed", reward = 2},
	{name = "Plant 60 Bombs", goal = 60, stat = "bombsPlanted", reward = 3},
	{name = "Win 5 Games", goal = 5, stat = "gamesWon", reward = 4}
}

function TaskManager.Init(dataManager, networkManager)
	DataManager = dataManager
	NetworkManager = networkManager

	-- Sync tasks when player joins
	Players.PlayerAdded:Connect(function(player)
		-- Wait for data to load
		task.wait(1)
		TaskManager.SyncTasks(player)
	end)

	-- Sync for existing players
	for _, player in Players:GetPlayers() do
		task.defer(function()
			TaskManager.SyncTasks(player)
		end)
	end
end

-- Get or create task progress
local function getTaskProgress(player)
	local taskData = DataManager.GetTaskData(player)

	if not taskData or not taskData.lastReset then
		taskData = {
			lastReset = os.time(),
			daily = {},
			bonus = {}
		}

		for i = 1, 3 do
			taskData.daily[i] = {progress = 0, completed = false, claimed = false}
			taskData.bonus[i] = {progress = 0, completed = false, claimed = false}
		end

		DataManager.SetTaskData(player, taskData)
	end

	-- Ensure all task slots exist
	for i = 1, 3 do
		if not taskData.daily[i] then
			taskData.daily[i] = {progress = 0, completed = false, claimed = false}
		end
		if not taskData.bonus[i] then
			taskData.bonus[i] = {progress = 0, completed = false, claimed = false}
		end
	end

	return taskData
end

-- Build task data for client
local function buildClientTaskData(player)
	local taskProgress = getTaskProgress(player)
	local clientData = {daily = {}, bonus = {}}

	for i = 1, 3 do
		local dailyDef = DAILY_TASKS[i]
		local bonusDef = BONUS_TASKS[i]
		local dailyProg = taskProgress.daily[i] or {progress = 0, completed = false}
		local bonusProg = taskProgress.bonus[i] or {progress = 0, completed = false}

		clientData.daily[i] = {
			name = dailyDef.name,
			goal = dailyDef.goal,
			progress = dailyProg.progress,
			completed = dailyProg.completed,
			reward = dailyDef.reward
		}

		clientData.bonus[i] = {
			name = bonusDef.name,
			goal = bonusDef.goal,
			progress = bonusProg.progress,
			completed = bonusProg.completed,
			reward = bonusDef.reward
		}
	end

	return clientData
end

-- Sync tasks to client
function TaskManager.SyncTasks(player)
	if not player or not player.Parent then return end

	if NetworkManager then
		local clientData = buildClientTaskData(player)
		NetworkManager.SendToClient(player, "Tasks", clientData)
		print("[TaskManager] Synced tasks to", player.Name)
	end
end

-- Record stat and check tasks
local function recordStat(player, statName)
	if not player or not player.Parent then return end

	DataManager.IncrementStat(player, statName, 1)
	local taskProgress = getTaskProgress(player)
	local updated = false

	-- Check daily tasks
	for i, taskDef in DAILY_TASKS do
		if taskDef.stat == statName then
			local prog = taskProgress.daily[i]
			if not prog.completed then
				prog.progress += 1
				if prog.progress >= taskDef.goal then
					prog.completed = true
					DataManager.AddCoins(player, taskDef.reward)
					if NetworkManager then
						NetworkManager.SendToClient(player, "TaskCompleted", {
							name = taskDef.name,
							reward = taskDef.reward,
							isBonus = false
						})
					end
					print("[TaskManager]", player.Name, "completed daily task:", taskDef.name)
				end
				updated = true
			end
		end
	end

	-- Check bonus tasks
	for i, taskDef in BONUS_TASKS do
		if taskDef.stat == statName then
			local prog = taskProgress.bonus[i]
			local dailyProg = taskProgress.daily[i]
			if dailyProg.completed and not prog.completed then
				prog.progress += 1
				if prog.progress >= taskDef.goal then
					prog.completed = true
					-- Reset bonus task for infinite loop
					prog.progress = 0
					prog.completed = false
					DataManager.AddCoins(player, taskDef.reward)
					if NetworkManager then
						NetworkManager.SendToClient(player, "TaskCompleted", {
							name = taskDef.name,
							reward = taskDef.reward,
							isBonus = true
						})
					end
					print("[TaskManager]", player.Name, "completed bonus task:", taskDef.name)
				end
				updated = true
			end
		end
	end

	if updated then
		DataManager.SetTaskData(player, taskProgress)
		TaskManager.SyncTasks(player)
	end
end

function TaskManager.RecordBombPlanted(player)
	recordStat(player, "bombsPlanted")
end

function TaskManager.RecordBombDefused(player)
	recordStat(player, "bombsDefused")
end

function TaskManager.RecordGamePlayed(player)
	recordStat(player, "gamesPlayed")
end

function TaskManager.RecordGameWon(player)
	recordStat(player, "gamesWon")
end

-- Expose as global
_G.TaskManager = TaskManager

print("[TaskManager] Loaded")
return TaskManager