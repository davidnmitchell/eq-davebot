local mq      = require('mq')
local co      = require('co')
local mychar  = require('mychar')
local netbots = require('netbots')
local dannet  = require('dannet')
require('eqclass')

local crowdcontrolbot = {}


--
-- Globals
--

local actionqueue = {}

local State = {}
local Config = {}
local MyClass = EQClass:new()

local CCRunning = false


--
-- Functions
--

local function log(msg)
	print('(crowdcontrolbot) ' .. msg)
end

local function do_target(target_id, func)
	local locked, lock = State.WaitOnAndAcquireLock(
		'target',
		'crowdcontrolbot'
	)
	assert(locked, 'Could not lock target')

	mq.TLO.Spawn(target_id).DoTarget()
	--mq.cmd('/target id ' .. target_id)
	co.delay(1000, function() return mq.TLO.Target.ID() == target_id end)
	assert(mq.TLO.Target.ID() == target_id, 'Did not target')

	co.delay(250)
	local value = func()

	State.ReleaseLock(
		'target',
		'crowdcontrolbot'
	)

	return value
end

local function IsControlled(spawn_id)
	return do_target(
		spawn_id,
		function()
			return mq.TLO.Target.Mezzed()
		end
	)
end

local function group_member_target_id(idx)
	local name = mq.TLO.Group.Member(idx).Name()
	local netbots_peer = netbots.PeerByName(name)
	if netbots_peer:len() > 0 then
		return mq.TLO.NetBots(netbots_peer).TargetID() or 0
	else
		return do_target(mq.TLO.Group.Member(idx).ID(), function() return mq.TLO.Me.TargetOfTarget.ID() end) or 0
	end
end

local function group_pet_target_id(idx)
	local name = mq.TLO.Group.Member(idx).Name()
	local dannet_peer = dannet.PeerByName(name)
	if dannet_peer:len() > 0 then
		return dannet.Observe(dannet_peer, 'Pet.Target.ID') or 0
	else
		return do_target(mq.TLO.Group.Member(idx).Pet.ID(), function() return mq.TLO.Me.TargetOfTarget.ID() end) or 0
	end
end

local function party_targets()
	local targets = {}
	for i=1, mq.TLO.Group.Members() do
		local member_target_id = group_member_target_id(i)
		if member_target_id ~= 0 then
			table.insert(targets, member_target_id)
		end

		if mq.TLO.Group.Member(i).Pet() ~= 'NO PET' then
			local member_pet_target_id = group_pet_target_id(i)
			if member_pet_target_id ~= nil and member_pet_target_id ~= 0 then
				table.insert(targets, member_pet_target_id)
			end
		end
	end
	---@diagnostic disable-next-line: undefined-field
	local main_assist_id = mq.TLO.Me.GroupAssistTarget.ID()
	if main_assist_id ~= nil and main_assist_id ~= 0 then
		table.insert(targets, main_assist_id)
	end
	return targets
end

local function WantToControl(idx, target_id, current_targets)
	for i, member_target_id in ipairs(current_targets) do
		if member_target_id == target_id then
			return false
		end
	end
	-- local log_string = ''
	-- for i, t_id in ipairs(current_targets) do
	-- 	if t_id ~= 0 then
	-- 		log_string = log_string .. ', ' .. (mq.TLO.Spawn(t_id).Name() or 'nil') .. '(' .. t_id .. ')'
	-- 	end
	-- end
	-- print('No match (' .. target_id .. ') :' .. log_string)
	return true
end

local function CCTargetByID(idx, target_id, current_targets, cast_function)
	if WantToControl(idx, target_id, current_targets) and not IsControlled(target_id) then
		local spell_key = Config:CrowdControl():Spell()
		local spell = Config:Spells():Spell(spell_key)
		local gem, err = Config:SpellBar():GemBySpell(spell)
		if gem < 1 then
			log(err)
		else
			local target_name = mq.TLO.Spawn(target_id).Name()
			if target_name then
				cast_function(spell.Name, gem, target_name)
			end
		end
	end
end


local function EnchanterCCMode()
	log('Crowd control active')
	CCRunning = true
	State.MarkCrowdControlActive()
	actionqueue.Wipe()
end

local function EnchanterCCTargetByID(idx, target_id, current_targets)
	CCTargetByID(
		idx,
		target_id,
		current_targets,
		function(spell, gem, name)
			actionqueue.AddUnique(
				ScpCast(
					spell,
					'gem' .. gem,
					Config:CrowdControl():MinMana(),
					3,
					target_id,
					1,
					mq.TLO.Spell(spell).CastTime.Raw() + 2000,
					10
				)
			)
		end
	)
end

local function BardCCMode()
	log('Crowd control active')
	CCRunning = true
	State.MarkCrowdControlActive()
	actionqueue.Wipe()
	mq.cmd('/attack off')
	mq.cmd('/twist clear')
	co.delay(250)
end

local function BardCCTargetByID(idx, target_id, current_targets)
	CCTargetByID(
		idx,
		target_id,
		current_targets,
		function(spell, gem, name)
			actionqueue.AddUnique(
				ScpCast(
					spell,
					'gem' .. gem,
					Config:CrowdControl():MinMana(),
					20,
					target_id,
					1,
					mq.TLO.Spell(spell).CastTime.Raw() + 2000,
					10
				)
			)

			-- log('Controlling ' .. name)
			-- mq.cmd('/target id ' .. target_id)
			-- co.delay(50)
			-- mq.cmd('/twist hold ' .. gem)
			-- while WantToControl(idx, target_id) and not IsControlled(target_id) and mq.TLO.Spawn(target_id).State() ~= "DEAD" and mq.TLO.Spawn(target_id).State() ~= "STUN" do
			-- 	co.delay(250)
			-- end
			-- if IsControlled(target_id) then
			-- 	log('Controlled ' .. name)
			-- end
		end
	)
end

local function dannet_observe_pet_targets()
	for i=1, mq.TLO.Group.Members() do
		if mq.TLO.Group.Member(i).Pet() ~= 'NO PET' then
			local dannet_peer = dannet.PeerByName(mq.TLO.Group.Member(i).Name())
			if dannet_peer:len() > 0 then
				local member_pet_target_id = dannet.Observe(dannet_peer, 'Pet.Target.ID')
			end
		end
	end
end

local function do_crowdcontrol(my_class)
	local i_am_primary = Config:CrowdControl():IAmPrimary()

	local threshold = 3
	if i_am_primary then
		threshold = 1
	end

	if my_class == 'Enchanter' then
		if mq.TLO.Me.XTarget() > threshold and mq.TLO.Me.PctMana() >= Config:CrowdControl():MinMana() then
			local current_targets = { }
			if not CCRunning then
				EnchanterCCMode()
				---@diagnostic disable-next-line: undefined-field
				table.insert(current_targets, mq.TLO.Me.GroupAssistTarget.ID())
			else
				current_targets = party_targets()
			end
			if i_am_primary then
				for i=1,mq.TLO.Me.XTarget() do
					EnchanterCCTargetByID(i, mq.TLO.Me.XTarget(i).ID(), current_targets)
					if mq.TLO.Me.XTarget() <= threshold then
						goto afterloop1
					end
				end
				::afterloop1::
			else
				for i=mq.TLO.Me.XTarget(),1,-1 do
					EnchanterCCTargetByID(i, mq.TLO.Me.XTarget(i).ID(), current_targets)
					if mq.TLO.Me.XTarget() <= threshold then
						goto afterloop2
					end
				end
				::afterloop2::
			end
		else
			if CCRunning then
				CCRunning = false
				State.MarkCrowdControlInactive()
			end
		end
	elseif my_class == 'Bard' then
		if mq.TLO.Me.XTarget() > threshold then
			local current_targets = { }
			if not CCRunning then
				BardCCMode()
				---@diagnostic disable-next-line: undefined-field
				table.insert(current_targets, mq.TLO.Me.GroupAssistTarget.ID())
			else
				current_targets = party_targets()
			end
			if i_am_primary then
				for i=1,mq.TLO.Me.XTarget() do
					BardCCTargetByID(i, mq.TLO.Me.XTarget(i).ID(), current_targets)
					if mq.TLO.Me.XTarget() <= threshold then
						goto afterloop3
					end
				end
				::afterloop3::
			else
				for i=mq.TLO.Me.XTarget(),1,-1 do
					BardCCTargetByID(i, mq.TLO.Me.XTarget(i).ID(), current_targets)
					if mq.TLO.Me.XTarget() <= threshold then
						goto afterloop4
					end
				end
				::afterloop4::
			end
		else
			if CCRunning then
				CCRunning = false
				State.MarkCrowdControlInactive()
			end
		end
	end
end


--
-- Init
--

function crowdcontrolbot.Init(state, cfg, aq)
	State = state
	Config = cfg
	actionqueue = aq
end


---
--- Main Loop
---

function crowdcontrolbot.Run()
	local observe_co = ManagedCoroutine:new(
		function()
			while true do
				dannet_observe_pet_targets()
				co.delay(10000)
			end
		end
	)
	log('Up and running')
	while true do
		if State.Mode ~= 1 and mychar.InCombat() then
			do_crowdcontrol(MyClass.Name)
		end
		observe_co:Resume()
		co.yield()
	end
end

return crowdcontrolbot