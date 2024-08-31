local mq = require('mq')
local str = require('str')
local mychar = require('mychar')
local target = require('target')
local spells = require('spells')
local heartbeat = require('heartbeat')
require('ini')
require('config')
require('botstate')
require('eqclass')


--
-- Globals
--

local ProcessName = 'castqueue'
local MyClass = EQClass:new()
local State = BotState:new(false, ProcessName, false, false)
local Config = CastQueueConfig:new()
local SpellBar = SpellBarConfig:new()

Running = true
PauseUntil = 0
Paused = false

Queue = {}
Casting = {}


local function log(msg)
	print('(' .. ProcessName .. ') ' .. msg)
end

local function add_to_queue(spell, gem, target_id, msg, min_mana_pct, min_target_hp_pct, max_tries, priority)
	log('Queueing ' .. spell .. ' with priority ' .. priority)
	table.insert(
		Queue,
		{
			spell=spell,
			gem=gem,
			target_id=target_id,
			msg=msg,
			min_mana_pct=min_mana_pct,
			min_target_hp_pct=min_target_hp_pct,
			priority=priority,
			max_tries=max_tries,
			at=mq.gettime()
		}
	)
	table.sort(
		Queue,
		function (spell1, spell2)
			if spell1.priority == spell2.priority then
				return spell1.spell:upper() > spell2.spell:upper()
			else
				return spell1.priority > spell2.priority
			end
		end
	)
end

local function add_unique_to_queue(spell, gem, target_id, msg, min_mana_pct, min_target_hp_pct, max_tries, priority)
	if Casting ~= nil and spell == Casting.spell and target_id == Casting.target_id then
		return
	end
	for i, sinfo in ipairs(Queue) do
		if spell == sinfo.spell and target_id == sinfo.target_id then
			return
		end
	end
	add_to_queue(spell, gem, target_id, msg, min_mana_pct, min_target_hp_pct, max_tries, priority)
end

local function highest_priority_spell_idx()
	local idx = 0
	local priority = 10
	for i, sinfo in ipairs(Queue) do
		if sinfo.priority < priority and target.IsAlive(sinfo.target_id) then

			local range = mq.TLO.Spell(sinfo.spell).Range()
			if range == nil then range = 200 end
			local distance = mq.TLO.Spawn(sinfo.target_id).Distance()
			if distance == nil then distance = 0 end

			local in_range = range == 0 or distance <= range
			local is_invisibility_on_me = sinfo.spell == 'Invisibility' and sinfo.target_id == mq.TLO.Me.ID()
			if in_range and (not is_invisibility_on_me or #Queue == 1) then
				idx = i
				priority = sinfo.priority
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

local function InRangeAndLoS(spell_name, target_id)
	local range = mq.TLO.Spell(spell_name).Range() or 200
	local distance = mq.TLO.Spawn(target_id).Distance() or 0
	local los = mq.TLO.Spawn(target_id).LineOfSight() or false

	return (range == 0 or distance <= range) and los
end

local function do_casting()
	local ready = mychar.ReadyToCast()
	if ready then
---@diagnostic disable-next-line: undefined-field
		local result = mq.TLO.Cast.Result()
		if result ~= nil and Casting ~= nil and result == 'CAST_IMMUNE' then
			log('IMMUNE!!!!')
			log(mq.TLO.Spawn(Casting.target_id).Name())
		end
		Casting = nil
	end
	if ready and has_spell_in_queue() then
		local me_id = mq.TLO.Me.ID()
		local spell = next_spell()
		if spell then
			local target_hp_pct = mq.TLO.Spawn(spell.target_id).PctHPs()

			if spell.target_id ~= 0 and not target.IsAlive(spell.target_id) then
				mq.cmd('/g (' .. ProcessName .. ')Skipping "' .. spell.msg .. '" because target is dead')
			elseif spell.target_id ~= 0 and target_hp_pct ~= nil and target_hp_pct < spell.min_target_hp_pct then
				mq.cmd('/g (' .. ProcessName .. ')Skipping "' .. spell.msg .. '" because target hit points are lower than ' .. spell.min_target_hp_pct)
			else
				local enough_mana = mq.TLO.Me.PctMana() >= spell.min_mana_pct

				if enough_mana and (spell.target_id == 0 or InRangeAndLoS(spell.spell, spell.target_id)) and not mq.TLO.Me.Invis('ANY')() then
					Casting = spell
					mq.cmd('/g (' .. ProcessName .. ')' .. Casting.msg)

					if Casting.target_id ~= 0 and Casting.target_id ~= me_id then
						mq.cmd('/target id ' .. Casting.target_id)
						mq.delay(250)
						mq.cmd('/face id ' .. Casting.target_id)
					end

					local cmd = '/casting "' .. Casting.spell .. '" ' .. Casting.gem .. ' -maxtries|' .. Casting.max_tries .. ' -invis'
					if Casting.target_id ~= 0 then
						cmd = cmd .. ' -targetid|' .. Casting.target_id
						local target_name = mq.TLO.Spawn(spell.target_id).Name() or "NIL"
						log('Casting ' .. Casting.spell .. ' on ' .. target_name)
					else
						log('Casting ' .. Casting.spell)
					end
					mq.cmd(cmd)
					--print(cmd)
					--mq.delay(1000)
				elseif mq.TLO.Me.Invis('ANY')() then
					log('Casting will break invisibility, dropping ' .. spell.spell .. ' on ' .. mq.TLO.Spawn(spell.target_id).Name())
				else
					table.insert(Queue, 1, spell)
				end
			end
		end
	elseif Casting ~= nil and Casting.priority and mychar.Casting() and has_spell_in_queue() and Queue[highest_priority_spell_idx()].priority < Casting.priority then
		mq.cmd('/g (' .. ProcessName .. ')Interrupting...')
		mq.cmd('/interrupt')
		table.insert(Queue, 1, Casting)
		Casting = nil
	end
end

local function concat(args, start)
	local s = args[start] or ''
    for i = start+1, #args, 1 do
		s = s .. ' ' .. args[i]
    end
	return s
end

local function parse_line(line)
	local parsed = {
		priority=8,
		target_id=0,
		gem=SpellBar:FirstOpenGem(State),
		spell='',
		message='',
		min_mana=0,
		min_target_hps=0,
		max_tries=1,
		unique=false
	}
	local parts = str.Split(line, '-')
	for i=1,#parts do
		if str.StartsWith(parts[i], 'priority|') then
			parsed.priority = tonumber(str.Trim(str.Split(parts[i], '|')[2]))
		elseif str.StartsWith(parts[i], 'target_id|') then
			parsed.target_id = tonumber(str.Trim(str.Split(parts[i], '|')[2]))
		elseif str.StartsWith(parts[i], 'gem|') then
			local gem = str.Trim(str.Split(parts[i], '|')[2])
			local num = tonumber(gem, 10)
			if num then
				parsed.gem = 'gem' .. num
			else
				parsed.gem = gem
			end
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
			parsed.unique = str.Trim(str.Split(parts[i], '|')[2]) == 'TRUE'
		end
	end
	if not parsed.message then
		parsed.message = 'Casting ' .. parsed.spell ..' from event'
	end
	return parsed
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
	add_to_queue(name, 'gem ' .. tonumber(gem), tonumber(target_id), 'Casting ' .. name ..' from event', 0, 0, 1, tonumber(priority))
end

-- local function command_cast_queue_add(line)
-- 	local parts = str.Split(line, '|')

-- 	local spell = parts[2]
-- 	local gem = parts[3]
-- 	local target_id = tonumber(parts[4])
-- 	local msg = parts[5]

-- 	local min_mana_pct = str.AsNumber(parts[6], 0)
-- 	local min_target_hp_pct = str.AsNumber(parts[7], 0)
-- 	local max_tries = str.AsNumber(parts[8], 1)	
-- 	local priority = str.AsNumber(parts[9], 5)

-- 	add_to_queue(spell, gem, target_id, msg, min_mana_pct, min_target_hp_pct, max_tries, priority)
-- end

-- local function command_cast_queue_add_unique(line)
-- 	local parts = str.Split(line, '|')

-- 	local spell = parts[2]
-- 	local gem = parts[3]
-- 	local target_id = tonumber(parts[4])
-- 	local msg = parts[5]

-- 	local min_mana_pct = str.AsNumber(parts[6], 0)
-- 	local min_target_hp_pct = str.AsNumber(parts[7], 0)
-- 	local max_tries = str.AsNumber(parts[8], 1)
-- 	local priority = str.AsNumber(parts[9], 5)

-- 	add_unique_to_queue(spell, gem, target_id, msg, min_mana_pct, min_target_hp_pct, max_tries, priority)
-- end

-- local function command_cast_queue_remove_all(line)
-- 	remove_all_from_queue()
-- end

-- local function command_cast_queue_pause(line)
-- 	PauseUntil = mq.gettime() + 20000
-- end

-- local function command_cast_queue_shutdown(line)
-- 	Running = false
-- end


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
	-- mq.event('castqueueadd', '#*#COMMAND CASTQUEUEADD #*#', command_cast_queue_add)
	-- mq.event('castqueueaddunique', '#*#COMMAND CASTQUEUEADDUNIQUE #*#', command_cast_queue_add_unique)
	-- mq.event('castqueueremoveall', '#*#COMMAND CASTQUEUEREMOVEALL', command_cast_queue_remove_all)
	-- mq.event('castqueuepause', '#*#COMMAND CASTQUEUEPAUSE', command_cast_queue_pause)
	-- mq.event('castqueueshutdown', '#*#COMMAND CASTQUEUESHUTDOWN', command_cast_queue_shutdown)
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
					local line = concat(args, 2)
					local parsed = parse_line(line)
					if parsed.unique then
						add_unique_to_queue(parsed.spell, parsed.gem, parsed.target_id, parsed.message, parsed.min_mana, parsed.min_target_hps, parsed.max_tries, parsed.priority)
					else
						add_to_queue(parsed.spell, parsed.gem, parsed.target_id, parsed.message, parsed.min_mana, parsed.min_target_hps, parsed.max_tries, parsed.priority)
					end
				end
			else
				log('Print is ' .. tostring(Config:Print(State)) .. ', PrintTimer is ' .. Config:PrintTimer(State))
			end
		end
	)

	local nextprint = mq.gettime() + Config:PrintTimer(State) * 1000
	while Running == true do
		mq.doevents()

		if PauseUntil ~= 0 and not Paused then
			Paused = true
			local seconds = (PauseUntil - mq.gettime()) / 1000
			log('Pausing for ' .. seconds .. ' seconds')
		end

		if not Paused then
			local time = mq.gettime()
			if Config:Print(State) and time >= nextprint then
				print('-----Queue-----')
				for i,spell in ipairs(Queue) do
					local target_name = mq.TLO.Spawn(spell.target_id).Name() or "NIL"
					local target_state = mq.TLO.Spawn(spell.target_id).State() or "NIL"
					print(i .. ':' .. spell.spell .. ':' .. target_name .. ':' .. target_state)
				end
				nextprint = time + Config:PrintTimer(State) * 1000
			end
			do_casting()

			Config:Reload(10000)
			SpellBar:Reload(10000)
		else
			if mq.gettime() >= PauseUntil then
				Paused = false
				PauseUntil = 0
				log('Resuming')
			end
		end

		heartbeat.SendHeartBeat(ProcessName)
		mq.delay(10)
	end

	log('Shutting down')
end


--
-- Execution
--

main()
