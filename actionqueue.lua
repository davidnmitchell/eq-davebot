local mq = require('mq')
local str = require('str')
local array = require('array')
local spells = require('spells')
local co = require('co')
require('eqclass')
require('actions.s_cast')

--
-- Priorities
--
-- 10 - CC
-- 20 - Group Heal
-- 30 - Single Heal
-- 40 - Debuff
-- 50 - Dot
-- 60 - Pet Heal
-- 70 - Nuke
-- 80 - Pet Cast
-- 90 - Buff
--

local actionqueue = {}


--
-- Globals
--

local State = {}
local Config = {}
local MyClass = EQClass:new()

local PauseUntil = 0
local Paused = false
local Interrupt = false

local Queue = {}
local Running = {}


local function log(msg)
	---@diagnostic disable-next-line: undefined-field
	mq.cmd.echo(string.format('\a-y(actionqueue) \a-w%s', msg))
end


function actionqueue.Add(script)
	log('Queueing \ay' .. script.Name .. ' \axwith priority \aw' .. script.Priority)
	script.Context = {}
	script.Coroutine = coroutine.create(
		function()
			script.Run(State, Config, script.Context)
			local finished = co.delay(script.Timeout, function() return script.IsFinished(State, Config, script.Context) end)
			if finished then
				script.PostAction(State, Config, script.Context)
				script.Callback()
			else
				log('Timed out waiting for ' .. script.Name .. ' \axto finish')
			end
		end
	)
	script.NotDead = function() return coroutine.status(script.Coroutine) ~= 'dead' end
	table.insert(
		Queue,
		script
	)

	table.sort(
		Queue,
		function (script1, script2)
			if script1.Priority == script2.Priority then
				return script1.Name:upper() > script2.Name:upper()
			else
				return script1.Priority < script2.Priority
			end
		end
	)
end

function actionqueue.AddUnique(script)
	local function is_same(s) return script.IsSame(s) end
	if array.Any(Running, is_same) then return end
	if array.Any(Queue, is_same) then return end
	actionqueue.Add(script)
end


local function highest_priority_ready_script_idx()
	local idx = 0
	local priority = 9999
	local size = #Queue
	for i = 1, size do
		local script = Queue[i]
		if script.Priority < priority then
			local skip, reason = script.ShouldSkip(State, Config, script.Context)
			if not skip and script.IsReady(State, Config, script.Context) then
				idx = i
				priority = script.Priority
			end
		end
	end
	return idx
end

local function lowest_priority_running_script_priority()
	local running_priority = 99999
	local size = #Running
	for i = 1, size do
		local script = Running[i]
		if script.Priority < running_priority and script.NotDead() then
			running_priority = script.Priority
		end
	end
	if running_priority == 99999 then
		return -1
	else
		return running_priority
	end
end

local function next_ready_script()
	local idx = highest_priority_ready_script_idx()
	if idx == 0 then
		return false, {}
	end
	return true, table.remove(Queue, idx)
end



function actionqueue.Wipe()
	if #Queue > 0 then
		while #Queue > 0 do table.remove(Queue, 1) end
		Interrupt = true
	end
end

local function find_skippable()
	local idx = 0
	local msg = ''
	local size = #Queue
	for i = 1, size do
		local skip, reason = Queue[i].ShouldSkip(State, Config, {})
		if skip then
			idx = i
			msg = reason
			break
		end
	end
	return idx, msg
end

local function prune_skippable()
	local dead_idx, msg = find_skippable()
	local i = 1
	while dead_idx > 0 and i <= #Queue do
		local script = table.remove(Queue, dead_idx)
		log('Skipped ' .. script.Name .. ' because ' .. msg)

		dead_idx, msg = find_skippable()
		i = i + 1
	end
end

local function done_running()
	return array.None(
		Running,
		function(script)
			return script.NotDead()
		end
	)
end

local function should_interrupt()
	if Interrupt then
		Interrupt = false
		return true
	end
	local idx = highest_priority_ready_script_idx()
	if idx > 0 then
		local running_priority = lowest_priority_running_script_priority()
		if Queue[idx] == nil then
			print('nil 1')
		end
		if Queue[idx].Priority == nil then
			print('nil 2')
		end
		return running_priority > 30 and Queue[idx].Priority <= 30 and Queue[idx].Priority < running_priority
	end
	return false
end

local function do_runs()
	local has_script, script = next_ready_script()
	if has_script then
		table.insert(Running, script)
		while not done_running() do
			local size = #Running
			for i = 1, size do
				local r_script = Running[i]
				if r_script.NotDead() then
					local r, err = coroutine.resume(r_script.Coroutine)
					if not r then
						print(r_script.Name .. ': ' .. err)
					end
				end
			end
			if should_interrupt() and #Running > 0 then
				log('Interrupting...')
				for i, r_script in ipairs(Running) do
					r_script.OnInterrupt(State, Config, r_script.Context)
				end
				---@diagnostic disable-next-line: undefined-field
				if not mq.TLO.Cast.Status() == 'I' then
					mq.cmd('/interrupt')
				end
				break
			end
			local last = Running[#Running]
			if not last.Blocking then
				has_script, script = next_ready_script()
				if has_script then
					table.insert(Running, script)
					log('Running ' .. script.Name)
				end
			end
			co.yield()
		end
		Running = {}
	end
end

local split = str.Split
local starts_with = str.StartsWith
local trim = str.Trim
local filtered = array.Filtered

local function split_key_value(kv)
	local parts = str.Split(kv, '|')
	return str.Trim(parts[1]), str.Trim(parts[2])
end

local function parse_line(line)
	local parsed = {
		gem=0,
		unique=false
	}
	local parts = filtered(split(line, '-'), function(s) return #s > 0 end)
	for i=1,#parts do
		local key, value = split_key_value(parts[i])
		if key == 'priority' then
			parsed.priority = tonumber(value)
		elseif key == 'target_id' then
			parsed.target_id = tonumber(value)
		elseif key == 'gem' then
			parsed.gem = value
		elseif key == 'spell' then
			parsed.spell = spells.ReferenceSpell(value)
		elseif key == 'message' then
			parsed.message = value
		elseif key == 'min_mana' then
			parsed.min_mana = tonumber(value)
		elseif key == 'min_target_hps' then
			parsed.min_target_hps = tonumber(value)
		elseif key == 'max_tries' then
			parsed.max_tries = tonumber(value)
		elseif key == 'unique' then
			parsed.unique = value:lower() == 'true'
		end
	end
	if parsed.gem == 0 then
		parsed.gem = Config.SpellBar.GemBySpellName(parsed.spell.Name)
		if parsed.gem == 0 then
			parsed.gem = Config.SpellBar.FirstOpenGem()
		end
	end
	if tonumber(parsed.gem) then
		parsed.gem = 'gem' .. parsed.gem
	end
	if not parsed.message then
		parsed.message = 'Casting ' .. parsed.spell ..' from event'
	end
	return ScpCast(
		parsed.spell,
		parsed.gem,
		parsed.min_mana,
		parsed.max_tries,
		parsed.target_id,
		parsed.min_target_hps,
		mq.TLO.Spell(parsed.spell).CastTime.Raw(),
		parsed.priority
	), parsed.unique
end

local function print_queue()
	print('-----Queue-----')
	for i, script in ipairs(Running) do
		print('A: ' .. script.Name)
	end
	for i, script in ipairs(Queue) do
		print(i .. ': ' .. script.Name)
	end
end

--
-- Events 
--

local function command_queue_spell(line, priority, target_id, gem, spell)
	local name = spells.ReferenceSpell(spell)
	if not name then
		log('Could not find anything for ' .. spell)
		return
	end
	actionqueue.Add(Cast:new(name, gem, target_id, 'Casting ' .. name ..' from event', 0, 0, 1, priority))
end


--
-- Coroutines
--

local print_co = ManagedCoroutine(
	function()
		local nextprint = mq.gettime() + Config.CastQueue.PrintTimer() * 1000
		while true do
			local time = mq.gettime()
			if Config.CastQueue.Print() and time >= nextprint then
				print_queue()
				nextprint = time + Config.CastQueue.PrintTimer() * 1000
			end

			co.yield()
		end
	end
)

local runs_co = ManagedCoroutine(
	function()
		while true do
			do_runs()
			prune_skippable()

			co.yield()
		end
	end
)

local prune_co = ManagedCoroutine(
	function()
		while true do

			co.delay(1000)
		end
	end
)


--
-- Main
--

local function do_scripts()
	if PauseUntil ~= 0 and not Paused then
		Paused = true
		local seconds = (PauseUntil - mq.gettime()) / 1000
		log('Pausing for ' .. seconds .. ' seconds')
	end

	if not Paused then
		print_co.Resume()
		runs_co.Resume()
	else
		prune_co.Resume()
		if mq.gettime() >= PauseUntil then
			Paused = false
			PauseUntil = 0
			log('Resuming')
		end
	end
end


--
-- Init
--

function actionqueue.Init(state, cfg)
	State = state
	Config = cfg

	-- mq.event('queuespell2', '#*#COMMAND QUEUESPELL #1# #2# #3# #4#', command_queue_spell)
	-- mq.bind(
	-- 	'/dbcq',
	-- 	function(...)
	-- 		local args = { ... }
	-- 		if #args > 0 then
	-- 			if args[1] == 'pause' then
	-- 				local timer = tonumber(args[2]) or 20
	-- 				PauseUntil = mq.gettime() + timer * 1000
	-- 			elseif args[1] == 'removeall' then
	-- 				actionqueue.Wipe()
	-- 			elseif args[1] == 'queue' then
	-- 				local line = str.Join(args, ' ', 2)
	-- 				local script, unique = parse_line(line)
	-- 				if unique then
	-- 					actionqueue.AddUnique(script)
	-- 				else
	-- 					actionqueue.Add(script)
	-- 				end
	-- 			end
	-- 		else
	-- 			log('Print is ' .. tostring(Config.CastQueue.Print()) .. ', PrintTimer is ' .. Config.CastQueue.PrintTimer())
	-- 		end
	-- 	end
	-- )
end


---
--- Main Loop
---

function actionqueue.Run()
	log('Up and running')
	while true do
		do_scripts()
		co.yield()
	end
end

return actionqueue