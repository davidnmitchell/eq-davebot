local mq = require('mq')
require('ini')
require('eqclass')
require('botstate')
local str = require('str')
local spells = require('spells')
local common = require('common')


--
-- Globals
--

MyClass = EQClass:new()
State = BotState:new('healbot', true, false)

Running = true
Enabled = true

Spells = {}
Groups = {}


--
-- Functions
--

function BuildIni(ini)
	print('Building heal config')

	local options = ini:Section('Heal Options')
	options:WriteBoolean('Enabled', true)
	if MyClass.IsHealer then
		options:WriteBoolean('DefaultHealGroupPets', false)
	end
	options:WriteNumber('DefaultMinMana', 0)
	options:WriteNumber('DefaultGem', 1)

	local heal_spells = ini:Section('Heal Spells')
	heal_spells:WriteString('single', 'Heals,Heals,Single')

	local heal_group_1 = ini:Section('Heal Group 1')
	heal_group_1:WriteString('Modes', '1,2,3,4,5,6,7,8,9')
	if MyClass.IsHealer then
		heal_group_1:WriteBoolean('HealGroupPets', false)
	end
	heal_group_1:WriteNumber('MinMana', 0)
	heal_group_1:WriteNumber('DefaultGem', 1)

	local heal_gems_1 = ini:Section('Heal Gems 1')
	heal_gems_1:WriteNumber('single', 1)

	if MyClass.IsHealer then
		local heal_targets_1 = ini:Section('Heal Cast Spell At Percent 1')
		heal_targets_1:WriteString('tank', 'single,75')
		heal_targets_1:WriteString('melee', 'single,65')
		heal_targets_1:WriteString('caster', 'single,65')
		if MyClass.HasGroupHeals then
			heal_targets_1:WriteString('group', 'group,65')
		end
		heal_targets_1:WriteString('pet', 'single,65')
	else
		local heal_targets_1 = ini:Section('Heal Cast Spell At Percent 1')
		heal_targets_1:WriteString('self', 'single,65')
		if MyClass.HasPet then
			heal_targets_1:WriteString('selfpet', 'single,65')
		end
	end
end

function LoadIni(ini)
	Enabled = ini:Boolean('Heal Options', 'Enabled', false)
	local default_heal_group_pets = ini:Boolean('Heal Options', 'DefaultHealGroupPets', false)
	local default_min_mana = ini:Number('Heal Options', 'DefaultMinMana', 0)
	local default_gem = ini:Number('Heal Options', 'DefaultGem', 1)

	Spells = ini:SectionToTable('Heal Spells')

	local i = 1
	while ini:HasSection('Heal Group ' .. i) do
		local group = ini:SectionToTable('Heal Group ' .. i)
		local modes = str.Split(group['Modes'], ',')
		common.TableValueToBooleanOrDefault(group, 'HealGroupPets', default_heal_group_pets)
		common.TableValueToNumberOrDefault(group, 'MinMana', default_min_mana)
		common.TableValueToNumberOrDefault(group, 'DefaultGem', default_gem)
		group['Gems'] = ini:SectionToTable('Heal Gems ' .. i)
		group['SpellAtPcts'] = ini:SectionToTable('Heal Cast Spell At Percent ' .. i)
		for idx,mode in ipairs(modes) do
			Groups[tonumber(mode)] = group
		end
		i = i + 1
	end

	return i - 1
end

function Setup()
	local ini = Ini:new()

	if ini:IsMissing('Heal Options', 'Enabled') then BuildIni(ini) end

	local groups = LoadIni(ini)

	print('Healbot loaded with ' .. groups .. ' groups')

	return ini
end

local function type_from_class(class)
	if class.IsCaster or class.IsHealer then
		return 'caster'
	else
		return 'melee'
	end
end

local function type_is_configured(type)
	return Groups[State.Mode].SpellAtPcts[type] ~= nil
end

local function spell_key_by_type(type)
	local parts = str.Split(Groups[State.Mode].SpellAtPcts[type], ',')
	return parts[1]
end

local function gem_by_type(type)
	local key = spell_key_by_type(type)
	local gem = Groups[State.Mode].Gems[key] or Groups[State.Mode].DefaultGem
	if gem == nil then
		print('No gem defined for ' .. key .. ', gotta quit')
		mq.delay(100)
		mq.exit()
	end
	return gem
end

local function at_pct_by_type(type)
	local parts = str.Split(Groups[State.Mode].SpellAtPcts[type], ',')
	return tonumber(parts[2])
end

function LowestHPsGroupMember()
	local groupSize = mq.TLO.Group.Members()
	local lowestMember = {id=0, hps=101}
	for i=0,groupSize do
		local pct_hps = mq.TLO.Group.Member(i).PctHPs()
		if pct_hps ~= nil then
			local class = EQClass:new(mq.TLO.Group.Member(i).Class.Name())
			local type = type_from_class(class)
			if pct_hps < lowestMember.hps and type_is_configured(type) and pct_hps <= at_pct_by_type(type) then
				lowestMember = {id=mq.TLO.Group.Member(i).ID(), name=mq.TLO.Group.Member(i).Name(), idx=i, hps=pct_hps, class=class, spell=Spells[spell_key_by_type(type)], gem=gem_by_type(type)}
			end
		end
	end
	return lowestMember
end

function CheckTank()
	if mq.TLO.Group.MainTank() ~= nil then
		local pct_hps = mq.TLO.Group.MainTank.PctHPs()
		if pct_hps ~= nil and pct_hps <= at_pct_by_type('tank') then
			local name = spells.ReferenceSpell(Spells[spell_key_by_type('tank')])
			spells.QueueSpellIfNotQueued(name, 'gem' .. gem_by_type('tank'), mq.TLO.Group.MainTank.ID(), 'Healing ' .. mq.TLO.Group.MainTank.Name() .. ' with ' .. name, 0, 0, 1, 3)
		end
	else
		if not NoTankWarningPrinted then
			NoTankWarningPrinted = true
			print('No MainTank set in group')
		end
	end
end

function CheckGroupMembers()
	local to_heal = LowestHPsGroupMember()
	if to_heal.id ~= 0 then
		local spell_name = spells.ReferenceSpell(to_heal.spell)
		spells.QueueSpellIfNotQueued(spell_name, 'gem' .. to_heal.gem, to_heal.id, 'Healing ' .. to_heal.name .. ' with ' .. spell_name, 0, 0, 1, 3)
	end
end

function GroupHeal()
	local spell_name = spells.ReferenceSpell(Spells[spell_key_by_type('group')])
	if mq.TLO.Me.CurrentMana() > mq.TLO.Spell(spell_name).Mana() then
		spells.QueueSpellIfNotQueued(spell_name, 'gem' .. gem_by_type('group'), mq.TLO.Me.ID(), 'Healing group with ' .. spell_name, 0, 0, 1, 2)
	end
end

function CheckPets()
	local groupSize = mq.TLO.Group.Members()
	for i=0,groupSize do
		if not mq.TLO.Group.Member(i).Pet() == nil then
			if mq.TLO.Group.Member(i).Pet.PctHPs() < at_pct_by_type('pet') then
				local name = spells.ReferenceSpell(Spells[spell_key_by_type('pet')])
				spells.QueueSpellIfNotQueued(name, 'gem' .. gem_by_type('pet'), mq.TLO.Group.Member(i).Pet.ID(), 'Healing ' .. mq.TLO.Group.Member(i).Name() .. '\'s pet with ' .. name, 0, 0, 1, 6)
			end
		end
	end
end

function CheckSelf()
	local pct_hps = mq.TLO.Me.PctHPs()
	if pct_hps ~= nil and pct_hps <= at_pct_by_type('self') then
		local spell_name = spells.ReferenceSpell(Spells[spell_key_by_type('self')])
		if spell_name then
			local spell_target = mq.TLO.Spell(spell_name).TargetType()
			if spell_target == 'LifeTap' then
				if mq.TLO.Target() then
					spells.QueueSpellIfNotQueued(spell_name, 'gem' .. gem_by_type('self'), mq.TLO.Target.ID(), 'Tapping ' .. mq.TLO.Target.Name() .. ' with ' .. spell_name, 0, 0, 1, 3)
				end
			else
				spells.QueueSpellIfNotQueued(spell_name, 'gem' .. gem_by_type('self'), mq.TLO.Me.ID(), 'Healing ' .. mq.TLO.Me.Name() .. ' with ' .. spell_name, 0, 0, 1, 3)
			end
		else
			print('Nothing found for ' .. Spells[spell_key_by_type('self')])
		end
	end
end

function CheckPet()
	local pct_hps = mq.TLO.Pet.PctHPs()
	local at_pct = at_pct_by_type('selfpet')
	if pct_hps and at_pct and pct_hps <= at_pct then
		local spell_name = spells.ReferenceSpell(Spells[spell_key_by_type('selfpet')])
		if spell_name then
			spells.QueueSpellIfNotQueued(spell_name, 'gem' .. gem_by_type('selfpet'), mq.TLO.Pet.ID(), 'Healing ' .. mq.TLO.Pet.Name() .. ' with ' .. spell_name, 0, 0, 1, 3)
		else
			print('Nothing found for ' .. Spells[spell_key_by_type('selfpet')])
		end
	end
end

function CheckHitPoints()
	if MyClass.IsHealer and mq.TLO.Group() then
		if type_is_configured('tank') then
			CheckTank()
		end

		if MyClass.HasGroupHeals then
			if mq.TLO.Group.Injured(at_pct_by_type('group'))() > 2 then
				GroupHeal()
			end
		end

		if mq.TLO.Group.Injured(95)() > 0 then CheckGroupMembers() end

		if Groups[State.Mode].HealGroupPets then CheckPets() end
	end
	if not MyClass.IsHealer then
		CheckSelf()
		if MyClass.HasPet then
			CheckPet()
		end
	end
end


--
-- Main
--

local function main()
	if MyClass.IsHealer or MyClass.Name == 'Shadow Knight' then
		local ini = Setup()
		local nextload = mq.gettime() + 10000

		while Running == true do
			mq.doevents()

			CheckHitPoints()

			local time = mq.gettime()
			if time >= nextload then
				LoadIni(ini)
				nextload = time + 10000
			end
			mq.delay(10)
		end
	else
		print('(healbot)No support for ' .. MyClass.Name)
		print('(healbot)Exiting...')
	end
end


--
-- Execution
--

main()
