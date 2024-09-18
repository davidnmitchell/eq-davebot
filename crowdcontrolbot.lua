local mq = require('mq')
local spells = require('spells')
local mychar = require('mychar')
local heartbeat = require('heartbeat')
require('eqclass')
require('config')


--
-- Globals
--

local ProcessName = 'crowdcontrolbot'
local MyClass = EQClass:new()
local Config = Config:new(ProcessName)

local Running = true
local CCRunning = false


--
-- Functions
--

local function log(msg)
	print('(' .. ProcessName .. ') ' .. msg)
end

local function IsControlled(spawn_id)
	local timeout = mq.gettime() + 3500
	while mq.TLO.Target.ID() ~= spawn_id and timeout > mq.gettime() do
		mq.cmd('/target id ' .. spawn_id)
		mq.delay(10)
	end
	return mq.TLO.Target.Mezzed()
	-- local count = mq.TLO.Spawn(spawn_id).BuffCount()
	-- if count == nil then count = 0 end
	-- for i=1,count do
	-- 	if mq.TLO.Spawn(spawn_id).Buff(i).Spell.Category() == 'Utility Detrimental' and mq.TLO.Spawn(spawn_id).Buff(i).Spell.Subcategory() == 'Enthrall' then
	-- 		return true
	-- 	end
	-- end
	-- return false
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
	mq.TLO.DaveBot.States.CrowdControlIsActive()
	mq.delay(100)
	mq.cmd('/attack off')
	mq.cmd('/twist clear')
end

function BardCCTargetByID(idx, target_id)
	CCTargetByID(
		idx,
		target_id,
		function(spell, gem, name)
			log('Controlling ' .. name)
			mq.cmd('/target id ' .. target_id)
			mq.delay(50)
			mq.cmd('/twist hold ' .. gem)
			while WantToControl(idx, target_id) and not IsControlled(target_id) and mq.TLO.Spawn(target_id).State() ~= "DEAD" and mq.TLO.Spawn(target_id).State() ~= "STUN" do
				mq.delay(250)
			end
			if IsControlled(target_id) then
				log('Controlled ' .. name)
			end
		end
	)
end

function CheckCC(my_class)
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
				mq.TLO.DaveBot.States.CrowdControlIsInactive()
			end
		end
	end
end


--
-- Main
--

local function main()
	if MyClass.IsCrowdController then
		while Running == true do
			mq.doevents()

			if Config:CrowdControl():Enabled() and mychar.InCombat() then
				CheckCC(MyClass.Name)
			end

			Config:Reload(10000)

			heartbeat.SendHeartBeat(ProcessName)
			mq.delay(10)
		end
	else
		log('No support for ' .. MyClass.Name)
		log('Exiting...')
	end
end


--
-- Execution
--

main()
