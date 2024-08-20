local mq = require('mq')
local str = require('str')
local mychar = require('mychar')
local target = require('target')
local spells = require('spells')


--
-- Globals
--

Running = true
Paused = false

Queue = {}
Casting = {}


--
-- Functions
--

local function add_to_queue(spell, gem, target_id, msg, min_mana_pct, min_target_hp_pct, max_tries, priority)
	print('Queueing ' .. spell .. ' with priority ' .. priority)
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
			max_tries=max_tries
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
		
			local range = mq.TLO.Me.Spell(sinfo.spell).Range()
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

local function do_casting()
	local ready = mychar.ReadyToCast()
	if ready then
		local result = mq.TLO.Cast.Result()
		if result ~= nil and Casting ~= nil and result == 'CAST_IMMUNE' then
			print('IMMUNE!!!!')
			print(mq.TLO.Spawn(Casting.target_id).Name())
		end
		Casting = nil
	end
	if ready and has_spell_in_queue() then
		local me_id = mq.TLO.Me.ID()
		local spell = next_spell()
		local my_mana_pct = mq.TLO.Me.PctMana()
		local target_hp_pct = mq.TLO.Spawn(spell.target_id).PctHPs()

		if spell ~= nil then
			if not target.IsAlive(spell.target_id) then
				mq.cmd('/g (cast_queue)Skipping "' .. spell.msg .. '" because target is dead')
			elseif target_hp_pct ~= nil and target_hp_pct < spell.min_target_hp_pct then
				mq.cmd('/g (cast_queue)Skipping "' .. spell.msg .. '" because target hit points are lower than ' .. spell.min_target_hp_pct)
			else
				local enough_mana = mq.TLO.Me.PctMana() >= spell.min_mana_pct
				
				local range = mq.TLO.Me.Spell(spell.spell).Range()
				if range == nil then range = 200 end
				local distance = mq.TLO.Spawn(spell.target_id).Distance()
				if distance == nil then distance = 0 end
				
				local in_range = range == 0 or distance <= range
				
				if enough_mana and in_range and not mq.TLO.Me.Invis('ANY')() then
					Casting = spell
					mq.cmd('/g (cast_queue)' .. Casting.msg)

					if Casting.target_id ~= me_id then
						mq.cmd('/target id ' .. Casting.target_id)
						mq.delay(250)
						mq.cmd('/face id ' .. Casting.target_id)
					end
					
					local cmd = '/casting "' .. Casting.spell .. '" ' .. Casting.gem .. ' -maxtries|' .. Casting.max_tries .. ' -invis -targetid|' .. Casting.target_id
					mq.cmd(cmd)
					print(cmd)
					--mq.delay(1000)
				elseif mq.TLO.Me.Invis('ANY')() then
					print('Casting will break invisibility, dropping ' .. spell.spell .. ' on ' .. mq.TLO.Spawn(spell.target_id).Name())
				else
					table.insert(Queue, 1, spell)
				end
			end
		end
	elseif Casting ~= nil and Casting.priority and mychar.Casting() and has_spell_in_queue() and Queue[highest_priority_spell_idx()].priority < Casting.priority then
		mq.cmd('/g (cast_queue)Interrupting...')
		mq.cmd('/interrupt')
		table.insert(Queue, 1, Casting)
		Casting = nil
	end
end


--
-- Events 
--

local function command_queue_spell(line, priority, target_id, gem, spell)
	local name = spells.ReferenceSpell(spell)
	if not name then
		print('(cast_queue)Could not find anything for ' .. spell)
		return
	end
	add_to_queue(name, 'gem ' .. tonumber(gem), tonumber(target_id), 'Casting ' .. name ..' from event', 0, 0, 1, tonumber(priority))
end

local function command_cast_queue_add(line)
	local parts = str.Split(line, '|')
	
	local spell = parts[2]
	local gem = parts[3]
	local target_id = tonumber(parts[4])
	local msg = parts[5]
	
	local min_mana_pct = str.AsNumber(parts[6], 0)
	local min_target_hp_pct = str.AsNumber(parts[7], 0)
	local max_tries = str.AsNumber(parts[8], 1)	
	local priority = str.AsNumber(parts[9], 5)
	
	add_to_queue(spell, gem, target_id, msg, min_mana_pct, min_target_hp_pct, max_tries, priority)
end

local function command_cast_queue_add_unique(line)
	local parts = str.Split(line, '|')
	
	local spell = parts[2]
	local gem = parts[3]
	local target_id = tonumber(parts[4])
	local msg = parts[5]
	
	local min_mana_pct = str.AsNumber(parts[6], 0)
	local min_target_hp_pct = str.AsNumber(parts[7], 0)
	local max_tries = str.AsNumber(parts[8], 1)	
	local priority = str.AsNumber(parts[9], 5)
	
	add_unique_to_queue(spell, gem, target_id, msg, min_mana_pct, min_target_hp_pct, max_tries, priority)
end

local function command_cast_queue_remove_all(line)
	remove_all_from_queue()
end

local function command_cast_queue_pause(line)
	Paused = true
end

local function command_cast_queue_shutdown(line)
	Running = false
end


--
-- Main
--

local every_5_seconds = 0

local function main()
	local my_class = mq.TLO.Me.Class.Name()

	if my_class ~= 'Shaman' and my_class ~= 'Druid' and my_class ~= 'Cleric' and my_class ~= 'Enchanter' and my_class ~= 'Ranger' and my_class ~= 'Paladin' and my_class ~= 'Shadow Knight' and my_class ~= 'Beastlandd' and my_class ~= 'Wizard' and my_class ~= 'Magician' and my_class ~= 'Necromancer' then
		print('(cast_queue)No support for ' .. my_class)
		print('(cast_queue)Exiting...')
		return
	end

	mq.event('queuespell', '#*#COMMAND QUEUESPELL #1# #2# #3# #4#', command_queue_spell)
	mq.event('castqueueadd', '#*#COMMAND CASTQUEUEADD #*#', command_cast_queue_add)
	mq.event('castqueueaddunique', '#*#COMMAND CASTQUEUEADDUNIQUE #*#', command_cast_queue_add_unique)
	mq.event('castqueueremoveall', '#*#COMMAND CASTQUEUEREMOVEALL', command_cast_queue_remove_all)
	mq.event('castqueuepause', '#*#COMMAND CASTQUEUEPAUSE', command_cast_queue_pause)
	mq.event('castqueueshutdown', '#*#COMMAND CASTQUEUESHUTDOWN', command_cast_queue_shutdown)

	while Running == true do
		mq.doevents()

		if every_5_seconds >= 500 then
			every_5_seconds = 0
			print('-----Queue-----')
			for i,spell in ipairs(Queue) do
				local target_state = mq.TLO.Spawn(spell.target_id).State()
				if not target_state then target_state = "NIL" end
				print(i .. ':' .. spell.spell .. ':' .. target_state)
			end
		end
		do_casting()
		
		if Paused then
			Paused = false
			print('(cast_queue)Pausing for 20 seconds')
			mq.delay(20000)
			print('(cast_queue)Finished pausing')
		else
			mq.delay(10)
			every_5_seconds = every_5_seconds + 10
		end
	end
end


--
-- Execution
--

main()
