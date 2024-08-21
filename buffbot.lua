local mq = require('mq')
require('ini')
require('eqclass')
require('botstate')
local str = require('str')
local spells = require('spells')
local mychar = require('mychar')
local dannet = require('dannet')
local common = require('common')


--
-- Globals
--

MyClass = EQClass:new()
State = BotState:new('buffbot', true, false)

Running = true
Enabled = true

Spells = {}
Groups = {}


--
-- Functions
--

function BuildIni(ini)
	print('Building buff config')

	local buff_options = ini:Section('Buff Options')
	buff_options:WriteBoolean('Enabled', false)
	buff_options:WriteNumber('DefaultMinMana', 20)
	buff_options:WriteNumber('DefaultGem', 8)

	local buff_spells = ini:Section('Buff Spells')
	buff_spells:WriteString('hps', 'Inner Fire')
	buff_spells:WriteString('hot', 'Regeneration')
	buff_spells:WriteString('agi', 'Spirit of Cat')

	local buff_group_1 = ini:Section('Buff Group 1')
	buff_group_1:WriteString('Modes', '1,2,3')
	buff_group_1:WriteNumber('MinMana', 20)
	buff_group_1:WriteNumber('DefaultGem', 8)

	local buff_gems_1 = ini:Section('Buff Gems 1')
	buff_gems_1:WriteNumber('hps', 5)
	buff_gems_1:WriteNumber('hot', 5)
	buff_gems_1:WriteNumber('agi', 5)

	local buff_packages_1 = ini:Section('Buff Packages 1')
	buff_packages_1:WriteString('tank', 'hps,hot')
	buff_packages_1:WriteString('plate', 'hps')
	buff_packages_1:WriteString('melee', 'hps')
	buff_packages_1:WriteString('caster', 'hps')
	buff_packages_1:WriteString('pet', 'hps')
	buff_packages_1:WriteString('self', 'hps')
	buff_packages_1:WriteString('selfpet', 'hps')

	local buff_group_2 = ini:Section('Buff Group 2')
	buff_group_2:WriteString('Modes', '4,5,6,7,8,9')
	buff_group_2:WriteNumber('MinMana', 20)
	buff_group_2:WriteNumber('DefaultGem', 8)

	local buff_gems_2 = ini:Section('Buff Gems 2')
	buff_gems_2:WriteNumber('hps', 5)

	local buff_packages_2 = ini:Section('Buff Packages 2')
	buff_packages_2:WriteString('tank', 'hps,hot')
	buff_packages_2:WriteString('plate', 'hps')
	buff_packages_2:WriteString('melee', 'hps')
	buff_packages_2:WriteString('caster', 'hps')
	buff_packages_2:WriteString('pet', 'hps')
	buff_packages_2:WriteString('self', 'hps')
	buff_packages_2:WriteString('selfpet', 'hps')
end

function Setup()
	local ini = Ini:new()

	if ini:IsMissing('Buff Options', 'Enabled') then BuildIni(ini) end

	Enabled = ini:Boolean('Buff Options', 'Enabled', false)
	local default_min_mana = ini:Number('Buff Options', 'DefaultMinMana', 20)
	local default_gem = ini:Number('Buff Options', 'DefaultGem', 8)

	Spells = ini:SectionToTable('Buff Spells')

	local i = 1
	while ini:HasSection('Buff Group ' .. i) do
		local group = ini:SectionToTable('Buff Group ' .. i)
		local modes = str.Split(group['Modes'], ',')
		common.TableValueToNumberOrDefault(group, 'MinMana', default_min_mana)
		common.TableValueToNumberOrDefault(group, 'DefaultGem', default_gem)
		group['Gems'] = ini:SectionToTable('Buff Gems ' .. i)
		group['Packages'] = ini:SectionToTable('Buff Packages ' .. i)
		for idx,mode in ipairs(modes) do
			Groups[tonumber(mode)] = group
		end
		i = i + 1
	end

	print('Buffbot loaded with ' .. (i-1) .. ' groups')
end

-- TODO: Item Buffs

function PeersPetHasBuff(buff_name, peer)
	local buff = dannet.Query(peer, 'Pet.Buff[' .. buff_name .. ']')
	return buff ~= 'NULL'
end

function HasBuff(buff_name, id)
	return mq.TLO.Spawn(id).Buff(buff_name)() ~= nil
end

function HasAura(aura_name)
	return mq.TLO.Me.Aura == aura_name
end

function CastBuffOn(buff_name, gem, id, char_name)
	if mq.TLO.Spawn(id)() and mq.TLO.Spawn(id).Distance() <= mq.TLO.Spell(buff_name).Range() then
		spells.QueueSpellIfNotQueued(buff_name, 'gem' .. gem, id, 'Buffing ' .. char_name .. ' with ' .. buff_name, Groups[State.Mode].MinMana, 0, 1, 9)
	end
end

function CheckOnBuffsForId(package_name, id, char_name)
	for i,tab_id in ipairs(str.Split(Groups[State.Mode].Packages[package_name], ',')) do
		local name = spells.ReferenceSpell(Spells[tab_id])
		if name then
			--if package_name == 'self' and name == 'Gift of Pure Though' then
				--print(HasBuff(name, id))
			--end
			if not HasBuff(name, id) then
				local gem = Groups[State.Mode].Gems[tab_id]
				if gem == nil then gem = Groups[State.Mode].DefaultGem end
				CastBuffOn(name, gem, id, char_name)
			end
		end
	end
end

function CheckOnBuffsForIdsPet(package_name, id, char_name)
	local peer = dannet.PeerById(id)
	if peer then
		for i,tab_id in ipairs(str.Split(Groups[State.Mode].Packages[package_name],',')) do
			local name = spells.ReferenceSpell(Spells[tab_id])
			if name then
				if not PeersPetHasBuff(name, peer) then
					local gem = Groups[State.Mode].Gems[tab_id]
					if gem == nil then gem = Groups[State.Mode].DefaultGem end
					CastBuffOn(name, gem, mq.TLO.Spawn(id).Pet.ID(), char_name)
				end
			end
		end
	else
		CheckOnBuffsForId(package_name, mq.TLO.Spawn(id).Pet.ID(), char_name)
	end
end

function CheckOnBuffsForMe(package_name)
	for i,tab_id in ipairs(str.Split(Groups[State.Mode].Packages[package_name], ',')) do
		local name = spells.ReferenceSpell(Spells[tab_id])
		if name then
			--if package_name == 'self' and name == 'Gift of Pure Though' then
				--print(HasBuff(name, id))
			--end
			if mq.TLO.Me.Buff(name)() == nil and name ~= mq.TLO.Me.Aura() then
				local gem = Groups[State.Mode].Gems[tab_id]
				if gem == nil then gem = Groups[State.Mode].DefaultGem end
				CastBuffOn(name, gem, mq.TLO.Me.ID(), mq.TLO.Me.Name())
			end
		end
	end
end

function CheckSelfBuffs()
	CheckOnBuffsForMe('self')
	--CheckOnBuffsForId('self', mq.TLO.Me.ID(), mq.TLO.Me.Name())
	CheckOnBuffsForId('selfpet', mq.TLO.Me.Pet.ID(), mq.TLO.Me.Pet.Name())
end

function CheckGroupBuffs()
	local class_name = ''
	local group_size = mq.TLO.Group.Members()
	for i=1,group_size do
		if mq.TLO.Me.ID() ~= mq.TLO.Group.Member(i).ID() and not mq.TLO.Group.Member(i).Offline() then
			if mq.TLO.Group.Member(i).MainTank() then
				CheckOnBuffsForId('tank', mq.TLO.Group.Member(i).ID(), mq.TLO.Group.Member(i).Name())
			else
				class_name = mq.TLO.Group.Member(i).Class.Name()
				if class_name == 'Shaman' or class_name == 'Cleric' or class_name == 'Wizard' or class_name == 'Magician' or class_name == 'Enchanter' or class_name == 'Necromancer' or class_name == 'Druid' then
					CheckOnBuffsForId('caster', mq.TLO.Group.Member(i).ID(), mq.TLO.Group.Member(i).Name())
				elseif class_name == 'Warrior' or class_name == 'Shadow Knight' or class_name == 'Paladin' then
					CheckOnBuffsForId('plate', mq.TLO.Group.Member(i).ID(), mq.TLO.Group.Member(i).Name())
				elseif class_name == 'Ranger' or class_name == 'Rogue' or class_name == 'Bard' or class_name == 'Berserker' or class_name == 'Beastlord' or class_name == 'Monk' then
					CheckOnBuffsForId('melee', mq.TLO.Group.Member(i).ID(), mq.TLO.Group.Member(i).Name())
				end
			end
		end
	end
end

function CheckPetBuffs()
	local group_size = mq.TLO.Group.Members()
	for i=0,group_size do
		if mq.TLO.Group.Member(i).Pet.ID() ~= 0 then
			local id = mq.TLO.Group.Member(i).ID()
			if id then
				CheckOnBuffsForIdsPet('pet', id, mq.TLO.Group.Member(i).Name() .. '\'s Pet')
			end
		end
	end
end

function CheckBuffs()
	CheckSelfBuffs()

	if mq.TLO.Me.Grouped() then
		CheckGroupBuffs()
		CheckPetBuffs()
	end
end


--
-- Main
--

local function main()
	Setup()

	while Running == true do
		mq.doevents()

		if Enabled and State.Mode ~= State.AutoCombatMode and not mychar.InCombat() then
			CheckBuffs()
		end
			
		mq.delay(10)
	end
end


--
-- Execution
--

main()
