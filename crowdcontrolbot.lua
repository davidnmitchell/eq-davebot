local mq = require('mq')
local co = require('co')
local spells = require('spells')
local mychar = require('mychar')
require('eqclass')

local crowdcontrolbot = {}


--
-- Globals
--

local Config = {}
local MyClass = EQClass:new()

local CCRunning = false


--
-- Functions
--

local function log(msg)
	print('(crowdcontrolbot) ' .. msg)
end

local function IsControlled(spawn_id)
	co.delay(
		3500,
		function()
			mq.cmd('/target id ' .. spawn_id)
			return mq.TLO.Target.ID() == spawn_id
		end
	)
	return mq.TLO.Target.Mezzed()
end

local function WantToControl(idx, target_id)
---@diagnostic disable-next-line: undefined-field
	local group_assist_target_id = mq.TLO.Me.GroupAssistTarget.ID()
	local have_group_assist = group_assist_target_id ~= nil and group_assist_target_id ~= 0
	local this_is_group_assist = target_id == group_assist_target_id
	local want_to_control = false
	if have_group_assist then
		if not this_is_group_assist then
			want_to_control = true
		end
	else
		if idx ~= 1 then
			want_to_control = true
		end
	end
	return want_to_control
end

local function CCTargetByID(idx, target_id, cast_function)
	if WantToControl(idx, target_id) and not IsControlled(target_id) then
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
	---@diagnostic disable-next-line: undefined-field
	mq.TLO.DaveBot.States.CrowdControlIsActive()
	spells.WipeQueue()
	mq.cmd('/interrupt')
end

local function EnchanterCCTargetByID(idx, target_id)
	CCTargetByID(
		idx,
		target_id,
		function(spell, gem, name)
			spells.QueueSpellIfNotQueued(spell, 'gem' .. gem, target_id, 'Controlling ' .. name, Config:CrowdControl():MinMana(), 1, 3, 10)
		end
	)
end

local function BardCCMode()
	log('Crowd control active')
	CCRunning = true
	---@diagnostic disable-next-line: undefined-field
	mq.TLO.DaveBot.States.CrowdControlIsActive()
	co.delay(100)
	mq.cmd('/attack off')
	mq.cmd('/twist clear')
end

local function BardCCTargetByID(idx, target_id)
	CCTargetByID(
		idx,
		target_id,
		function(spell, gem, name)
			log('Controlling ' .. name)
			mq.cmd('/target id ' .. target_id)
			co.delay(50)
			mq.cmd('/twist hold ' .. gem)
			while WantToControl(idx, target_id) and not IsControlled(target_id) and mq.TLO.Spawn(target_id).State() ~= "DEAD" and mq.TLO.Spawn(target_id).State() ~= "STUN" do
				co.delay(250)
			end
			if IsControlled(target_id) then
				log('Controlled ' .. name)
			end
		end
	)
end

local function do_crowdcontrol(my_class)
	local i_am_primary = Config:CrowdControl():IAmPrimary()

	local threshold = 3
	if i_am_primary then
		threshold = 1
	end

	if my_class == 'Enchanter' then
		if mq.TLO.Me.XTarget() > threshold and mq.TLO.Me.PctMana() >= Config:CrowdControl():MinMana() then
			if not CCRunning then
				EnchanterCCMode()
			end
			if i_am_primary then
				for i=1,mq.TLO.Me.XTarget() do
					EnchanterCCTargetByID(i, mq.TLO.Me.XTarget(i).ID())
					if mq.TLO.Me.XTarget() <= threshold then
						goto afterloop1
					end
				end
				::afterloop1::
			else
				for i=mq.TLO.Me.XTarget(),1,-1 do
					EnchanterCCTargetByID(i, mq.TLO.Me.XTarget(i).ID())
					if mq.TLO.Me.XTarget() <= threshold then
						goto afterloop2
					end
				end
				::afterloop2::
			end
		else
			if CCRunning then
				CCRunning = false
				---@diagnostic disable-next-line: undefined-field
				mq.TLO.DaveBot.States.CrowdControlIsInactive()
			end
		end
	elseif my_class == 'Bard' then
		if mq.TLO.Me.XTarget() > threshold then
			if not CCRunning then
				BardCCMode()
			end
			if i_am_primary then
				for i=1,mq.TLO.Me.XTarget() do
					BardCCTargetByID(i, mq.TLO.Me.XTarget(i).ID())
					if mq.TLO.Me.XTarget() <= threshold then
						goto afterloop3
					end
				end
				::afterloop3::
			else
				for i=mq.TLO.Me.XTarget(),1,-1 do
					BardCCTargetByID(i, mq.TLO.Me.XTarget(i).ID())
					if mq.TLO.Me.XTarget() <= threshold then
						goto afterloop4
					end
				end
				::afterloop4::
			end
		else
			if CCRunning then
				CCRunning = false
				---@diagnostic disable-next-line: undefined-field
				mq.TLO.DaveBot.States.CrowdControlIsInactive()
			end
		end
	end
end


--
-- Init
--

function crowdcontrolbot.Init(cfg)
	Config = cfg
end


---
--- Main Loop
---

function crowdcontrolbot.Run()
	log('Up and running')
	while true do
		if mychar.InCombat() then
			do_crowdcontrol(MyClass.Name)
		end
		co.yield()
	end
end

return crowdcontrolbot