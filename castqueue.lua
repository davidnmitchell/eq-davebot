local mq = require('mq')
local str = require('str')
local mychar = require('mychar')
local target = require('target')
local spells = require('spells')
local heartbeat = require('heartbeat')
local co = require('co')
require('ini')
require('config')
require('eqclass')
require('cast')

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

--
-- Globals
--

local ProcessName = 'castqueue'
local MyClass = EQClass:new()
local Config = Config:new(ProcessName)

Running = true
PauseUntil = 0
Paused = false

Queue = {}
Casting = {}
Immune = {}


local function log(msg)
	print('(' .. ProcessName .. ') ' .. msg)
end

local function announce(msg)
	mq.cmd('/g ' .. msg)
end

local function add_to_queue(cast)
	log('Queueing ' .. cast:SpellName() .. ' with priority ' .. cast:Priority())
	table.insert(
		Queue,
		cast
	)
	table.sort(
		Queue,
		function (cast1, cast2)
			if cast1:Priority() == cast2:Priority() then
				return cast1:SpellName():upper() > cast2:SpellName():upper()
			else
				return cast1:Priority() < cast2:Priority()
			end
		end
	)
end

local function add_unique_to_queue(cast)
	if cast:IsSame(Casting) then
		return
	end
	for i, q_cast in ipairs(Queue) do
		if cast:IsSame(q_cast) then
			return
		end
	end
	add_to_queue(cast)
end

local function highest_priority_spell_idx()
	local idx = 0
	local priority = 999
	for i, q_cast in ipairs(Queue) do
		if q_cast:Priority() < priority and (not q_cast:HasTarget() or q_cast:TargetIsAlive()) then
			if (not q_cast:HasTarget() or q_cast:InRange()) and (not q_cast:IsInvisibilityOnMe() or #Queue == 1) then
				idx = i
				priority = q_cast:Priority()
			end
		end
	end
	if idx == 0 then idx = 1 end
	return idx
end

local function has_spell_in_queue()
	return #Queue > 0
end

local function next_spell()
	return table.remove(Queue, highest_priority_spell_idx())
end

local function remove_all_from_queue()
	while has_spell_in_queue() do next_spell() end
end

local function find_dead()
	local idx = 0
	for i, q_cast in ipairs(Queue) do
		if q_cast:HasTarget() and not q_cast:TargetIsAlive() then
			idx = i
		end
	end
	return idx
end

local function prune_dead()
	local dead_idx = find_dead()
	local i = 1
	while dead_idx > 0 and i <= #Queue do
		co.yield()

		local cast = table.remove(Queue, dead_idx)
		if cast ~= nil then cast:Skip('target is dead') end

		dead_idx = find_dead()
		i = i + 1
	end
end


local function i_am_invisible()
	return mq.TLO.Me.Invis('ANY')()
end

local function is_immune(cast)
	for i, i_cast in ipairs(Immune) do
		if cast:IsSame(i_cast) then return true end
	end
	return false
end

local function do_casting()
	local ready = mychar.ReadyToCast()
	if ready then
---@diagnostic disable-next-line: undefined-field
		local result = mq.TLO.Cast.Result()
		if result ~= nil and Casting ~= nil and result == 'CAST_IMMUNE' then
			log('IMMUNE!!!!')
			table.insert(Immune, Casting)
		end
		Casting = nil
	end
	if ready and has_spell_in_queue() then
		local me_id = mq.TLO.Me.ID()
		local cast = next_spell()
		if cast then
			if cast:HasTarget() and not cast:TargetIsAlive() then
				cast:Skip('target is dead')
			elseif is_immune(cast) then
				cast:Skip('target is immune')
			elseif cast:HasTarget() and cast:TargetHPsAreTooLow() then
				cast:Skip('target hit points are too low')
			else
				if cast:IHaveEnoughMana() and (not cast:HasTarget() or (cast:InRange() and cast:LineOfSight())) and not i_am_invisible() then
					Casting = cast
					Casting:Execute()
				elseif i_am_invisible() then
					local msg = 'Casting will break invisibility, waiting to cast ' .. cast:SpellName()
					if cast:HasTarget() then
						msg = msg .. ' on ' .. cast:TargetName()
					end
					log(msg)
					table.insert(Queue, 1, cast)
					co.delay(1000)
				else
					table.insert(Queue, 1, cast)
				end
			end
		end
	elseif Casting ~= nil and mychar.Casting() and has_spell_in_queue() and Queue[highest_priority_spell_idx()]:Priority() < Casting:Priority() then
		log('Interrupting...')
		announce('Interrupting...')
		mq.cmd('/interrupt')
		table.insert(Queue, 1, Casting)
		Casting = nil
	end
end

local function parse_line(line)
	local parsed = {
		gem=Config:SpellBar():FirstOpenGem(),
		unique=false
	}
	local parts = str.Split(line, '-')
	for i=1,#parts do
		if str.StartsWith(parts[i], 'priority|') then
			parsed.priority = tonumber(str.Trim(str.Split(parts[i], '|')[2]))
		elseif str.StartsWith(parts[i], 'target_id|') then
			parsed.target_id = tonumber(str.Trim(str.Split(parts[i], '|')[2]))
		elseif str.StartsWith(parts[i], 'gem|') then
			parsed.gem = str.Trim(str.Split(parts[i], '|')[2])
		elseif str.StartsWith(parts[i], 'spell|') then
			parsed.spell = spells.ReferenceSpell(str.Trim(str.Split(parts[i], '|')[2]))
		elseif str.StartsWith(parts[i], 'message|') then
			parsed.message = str.Trim(str.Split(parts[i], '|')[2])
		elseif str.StartsWith(parts[i], 'min_mana|') then
			parsed.min_mana = tonumber(str.Trim(str.Split(parts[i], '|')[2]))
		elseif str.StartsWith(parts[i], 'min_target_hps|') then
			parsed.min_target_hps = tonumber(str.Trim(str.Split(parts[i], '|')[2]))
		elseif str.StartsWith(parts[i], 'max_tries|') then
			parsed.max_tries = tonumber(str.Trim(str.Split(parts[i], '|')[2]))
		elseif str.StartsWith(parts[i], 'unique|') then
			parsed.unique = str.Trim(str.Split(parts[i], '|')[2]):lower() == 'true'
		end
	end
	if not parsed.message then
		parsed.message = 'Casting ' .. parsed.spell ..' from event'
	end
	return Cast:new(parsed.spell, parsed.gem, parsed.target_id, parsed.message, parsed.min_mana, parsed.min_target_hps, parsed.max_tries, parsed.priority), parsed.unique
end

local function print_queue()
	print('-----Queue-----')
	if Casting then
		if Casting:HasTarget() then
			print('c:' .. Casting:SpellName() .. ':' .. Casting:TargetName())
		else
			print('c:' .. Casting:SpellName())
		end
	end
	for i, q_cast in ipairs(Queue) do
		if q_cast:HasTarget() then
			print(i .. ':' .. q_cast:SpellName() .. ':' .. q_cast:TargetName())
		else
			print(i .. ':' .. q_cast:SpellName())
		end
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
	add_to_queue(Cast:new(name, gem, target_id, 'Casting ' .. name ..' from event', 0, 0, 1, priority))
end


--
-- Coroutines
--

local print_co = ManagedCoroutine:new(
	function()
		local nextprint = mq.gettime() + Config:CastQueue():PrintTimer() * 1000
		while true do
			local time = mq.gettime()
			if Config:CastQueue():Print() and time >= nextprint then
				print_queue()
				nextprint = time + Config:CastQueue():PrintTimer() * 1000
			end

			co.yield()
		end
	end
)

local cast_co = ManagedCoroutine:new(
	function()
		while true do
			do_casting()

			co.yield()
		end
	end
)

local prune_co = ManagedCoroutine:new(
	function()
		while true do
			prune_dead()

			co.delay(1000)
		end
	end
)

local reload_co = ManagedCoroutine:new(
	function()
		while true do
			Config:Reload(10000)

			co.yield()
		end
	end
)


--
-- Main
--

local function main()

	if not MyClass.HasSpells then
		log('No support for ' .. MyClass.Name)
		log('Exiting...')
		return
	end

	mq.event('queuespell', '#*#COMMAND QUEUESPELL #1# #2# #3# #4#', command_queue_spell)
	mq.bind(
		'/dbcq',
		function(...)
			local args = { ... }
			if #args > 0 then
				if args[1] == 'shutdown' then
					Running = false
				elseif args[1] == 'pause' then
					local timer = tonumber(args[2]) or 20
					PauseUntil = mq.gettime() + timer * 1000
				elseif args[1] == 'removeall' then
					remove_all_from_queue()
				elseif args[1] == 'queue' then
					local line = str.Join(args, 2)
					local cast, unique = parse_line(line)
					if unique then
						add_unique_to_queue(cast)
					else
						add_to_queue(cast)
					end
				end
			else
				log('Print is ' .. tostring(Config:CastQueue():Print()) .. ', PrintTimer is ' .. Config:CastQueue():PrintTimer())
			end
		end
	)

	while Running == true do
		mq.doevents()

		if PauseUntil ~= 0 and not Paused then
			Paused = true
			local seconds = (PauseUntil - mq.gettime()) / 1000
			log('Pausing for ' .. seconds .. ' seconds')
		end

		if not Paused then
			print_co:Resume()
			cast_co:Resume()
		else
			if mq.gettime() >= PauseUntil then
				Paused = false
				PauseUntil = 0
				log('Resuming')
			end
		end

		prune_co:Resume()
		reload_co:Resume()

		heartbeat.SendHeartBeat(ProcessName)
		mq.delay(1)
	end

	log('Shutting down')
end


--
-- Execution
--

main()
