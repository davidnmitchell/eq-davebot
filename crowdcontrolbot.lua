local mq = require('mq')
require('ini')
require('botstate')
local str = require('str')
local spells = require('spells')


--
-- Globals
--

MyClass = EQClass:new()
State = BotState:new('crowdcontrolbot', false, false)

Running = true
Enabled = true

Groups = {}


--
-- Setup
--

function BuildIni(ini)
	print('Building crowd control config')

	local cc_options = ini:Section('Crowd Control Options')
	cc_options:WriteBoolean('Enabled', false)
	cc_options:WriteBoolean('DefaultIAmPrimary', false)
	cc_options:WriteNumber('DefaultMinMana', 10)
	cc_options:WriteNumber('DefaultGem', 1)

	local cc1 = ini:Section('Crowd Control 1')
	cc1:WriteString('Modes', '5,6,7,8,9')
	cc1:WriteBoolean('IAmPrimary', false)
	cc1:WriteNumber('MinMana', 10)
	cc1:WriteString('Spell', 'Utility Detrimental,Enthrall,Single')
	cc1:WriteNumber('Gem', 1)
end

function Setup()
	local ini = Ini:new()

	if ini:IsMissing('Crowd Control Options', 'Enabled') then BuildIni(ini) end

	local options = ini:Section('Crowd Control Options')
	Enabled = options:Boolean('Enabled', false)
	local default_primary = options:Boolean('DefaultIAmPrimary', false)
	local default_min_mana = options:Number('DefaultMinMana', 10)
	local default_gem = options:Number('DefaultGem', 1)

	local i = 1
	while ini:HasSection('Crowd Control ' .. i) do
		local group = {}
		local group = ini:SectionToTable('Crowd Control ' .. i)
		local modes = str.Split(group['Modes'], ',')
		if group['IAmPrimary'] == nil then group['IAmPrimary'] = default_primary end
		if group['MinMana'] == nil then group['MinMana'] = default_min_mana end
		if group['Gem'] == nil then group['Gem'] = default_gem end
		for idx,mode in ipairs(modes) do
			Groups[tonumber(mode)] = group
		end
		i = i + 1
	end

	print('Crowd control config loaded. ' .. (i-1) .. ' groups.')
end


--
-- Functions
--

function IsControlled(spawn_id)
	local count = mq.TLO.Spawn(spawn_id).BuffCount()
	if count == nil then count = 0 end
	for i=1,count do
		if mq.TLO.Spawn(spawn_id).Buff(i).Spell.Category() == 'Utility Detrimental' and mq.TLO.Spawn(spawn_id).Buff(i).Spell.Subcategory() == 'Enthrall' then
			return true
		end
	end
	return false
end

function EnchanterCCMode()
	print('Crowd control mode')
	CCRunning = true
	mq.cmd('/echo NOTIFY CCACTIVE')
	spells.WipeQueue()
	mq.cmd('/interrupt')
end

function EnchanterCCTargetByID(idx, target_id, cc_spell)
	local have_group_assist = mq.TLO.Me.GroupAssistTarget.ID() ~= nil and mq.TLO.Me.GroupAssistTarget.ID() ~= 0
	local this_is_group_assist = target_id == mq.TLO.Me.GroupAssistTarget.ID()
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
	if want_to_control and not IsControlled(target_id) then
		local name = mq.TLO.Spawn(target_id).Name()
		if name ~= nil then
			spells.QueueSpellIfNotQueued(cc_spell, 'gem' .. Groups[State.Mode].Gem, target_id, 'Controlling ' .. name, Groups[State.Mode].MinMana, 1, 3, 1)
		end
	end
end

function BardCCMode(cc_spell)
	print('Crowd control mode')
	CCRunning = true
	mq.cmd('/echo NOTIFY CCACTIVE')
	mq.delay(100)
	mq.cmd('/attack off')
	mq.cmd('/twist clear')
end

function BardCCTargetByID(target_id)
	if target_id ~= mq.TLO.Me.GroupAssistTarget.ID() and not IsControlled(target_id) then
		print('Controlling ' .. mq.TLO.Spawn(target_id).Name())
		mq.cmd('/target id ' .. target_id)
		mq.delay(50)
		mq.cmd('/twist hold ' .. Groups[State.Mode].Gem)
		while not IsControlled(target_id) and target_id ~= mq.TLO.Me.GroupAssistTarget.ID() and mq.TLO.Spawn(target_id).State() ~= "DEAD" and mq.TLO.Spawn(target_id).State() ~= "STUN" do
			mq.delay(250)
		end
		if IsControlled(target_id) then
			print('Controlled ' .. mq.TLO.Spawn(target_id).Name())
		end
	end
end

function CheckCC(my_class)
	if State.Mode == State.AutoCombatMode then
		local cc_spell = spells.ReferenceSpell(Groups[State.Mode].Spell)

		local threshold = 3
		if Groups[State.Mode].IAmPrimaryCC then
			threshold = 1
		end
		
		if my_class == 'Enchanter' then
			if mq.TLO.Me.XTarget() > threshold and mq.TLO.Me.PctMana() >= Groups[State.Mode].MinMana and cc_spell ~= nil then
				if not CCRunning then
					EnchanterCCMode()
				end
				if Groups[State.Mode].IAmPrimaryCC then
					for i=1,mq.TLO.Me.XTarget() do
						EnchanterCCTargetByID(i, mq.TLO.Me.XTarget(i).ID(), cc_spell)
						if mq.TLO.Me.XTarget() <= threshold then
							goto afterloop1
						end
					end
					::afterloop1::
				else
					for i=mq.TLO.Me.XTarget(),1,-1 do
						EnchanterCCTargetByID(i, mq.TLO.Me.XTarget(i).ID(), cc_spell)
						if mq.TLO.Me.XTarget() <= threshold then
							goto afterloop2
						end
					end
					::afterloop2::
				end
			else
				if CCRunning then
					CCRunning = false
					mq.cmd('/echo NOTIFY CCINACTIVE')
				end
			end
		elseif my_class == 'Bard' then
			if mq.TLO.Me.XTarget() > threshold and cc_spell then
				if not CCRunning then
					BardCCMode(cc_spell)
				end
				if Groups[State.Mode].IAmPrimaryCC then
					for i=1,mq.TLO.Me.XTarget() do
						BardCCTargetByID(mq.TLO.Me.XTarget(i).ID())
						if mq.TLO.Me.XTarget() <= threshold then
							goto afterloop3
						end
					end
					::afterloop3::
				else
					for i=mq.TLO.Me.XTarget(),1,-1 do
						BardCCTargetByID(mq.TLO.Me.XTarget(i).ID())
						if mq.TLO.Me.XTarget() <= threshold then
							goto afterloop4
						end
					end
					::afterloop4::
				end
			else
				if CCRunning then
					CCRunning = false
					mq.cmd('/echo NOTIFY CCINACTIVE')
				end
			end
		end
	end
end

function CheckSpellBar()
	if Enabled then
		local spell = spells.ReferenceSpell(Groups[State.AutoCombatMode].Spell)
		if spell ~= nil then
			if mq.TLO.Me.Gem(Groups[State.AutoCombatMode].Gem).Name() ~= spell then
				mq.cmd('/memorize "' .. spell .. '" gem' .. Groups[State.AutoCombatMode].Gem)
				while not mq.TLO.Cast.Ready(Groups[State.AutoCombatMode].Gem)() do
					mq.delay(10)
				end
			end
		end
	end
end


--
-- Main
--
-- TODO: have all CC members communicate
function main()
	local am_cc = false

	local my_class = mq.TLO.Me.Class.Name()
	if my_class == 'Enchanter' or my_class == 'Bard' then
		am_cc = true
	end

	if am_cc then
		Setup()
	else
		print('(crowdcontrolbot)No support for ' .. my_class)
		print('(crowdcontrolbot)Exiting...')
		return
	end

	while Running == true do
		mq.doevents()

		CheckSpellBar()
		CheckCC(my_class)
		
		mq.delay(10)
	end
end


--
-- Execution
--

main()
