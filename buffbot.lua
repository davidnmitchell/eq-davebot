local mq      = require('mq')
local co      = require('co')
local str     = require('str')
local common  = require('common')
local netbots = require('netbots')
local mychar  = require('mychar')
local group   = require('group')
require('eqclass')
require('actions.s_cast')
require('actions.s_bardcastaura')


local buffbot = {}

--
-- Globals
--

local actionqueue = {}

local Config = {}
local State = {}
local MyClass = EQClass:new()

local LastAura = ""
local Exceptions = {}


--
-- Functions
--

local function log(msg)
	print('(buffbot) ' .. msg)
end

local function excepted(spell_name, target_id)
	return (Exceptions[target_id] and Exceptions[target_id][spell_name] and Exceptions[target_id][spell_name] + Config:Buff():BackoffTimer() > mq.gettime()) or false
end

local function netbots_peer_has_buff(spell_name, peer)
	for i, spell_id in ipairs(str.Split(mq.TLO.NetBots(peer).Buff(), ' ')) do
		if mq.TLO.Spell(spell_id).Name() == spell_name then
			return true
		end
	end
	for i, spell_id in ipairs(str.Split(mq.TLO.NetBots(peer).ShortBuff(), ' ')) do
		local n = mq.TLO.Spell(spell_id).Name()
		if n == spell_name or str.StartsWith(n, spell_name) then
			return true
		end
	end
	return false
end

local function netbots_peer_pet_has_buff(spell_name, peer)
	for i, spell_id in ipairs(str.Split(mq.TLO.NetBots(peer).PetBuff(), ' ')) do
		if mq.TLO.Spell(spell_id).Name() == spell_name then
			return true
		end
	end
	return false
end

local function HasBuff(spell_name, target_id)
	if common.ArrayHasValue(netbots.PeerIds(), target_id) then
		return netbots_peer_has_buff(spell_name, netbots.PeerById(target_id))
	elseif common.ArrayHasValue(netbots.PeerPetIds(), target_id) then
		return netbots_peer_pet_has_buff(spell_name, netbots.PeerByPetId(target_id))
	else
		if target_id == mq.TLO.Me.ID() then
			return mq.TLO.Me.Buff(spell_name)() ~= nil or mq.TLO.Me.Song(spell_name)() ~= nil
		else
			return mq.TLO.Spawn(target_id).Buff(spell_name)() ~= nil
		end
	end
end

local function CastBuffOn(buff_name, gem, id, char_name, order)
	assert(id)
	assert(buff_name)
	if mq.TLO.Spawn(id)() and mq.TLO.Spawn(id).Distance() <= mq.TLO.Spell(buff_name).Range() then
		local priority = 90 + order
		if buff_name == 'Invisibility' and id == mq.TLO.Me.ID() then
			priority = 101
		end
		local target_id = id
		local target_type = mq.TLO.Spell(buff_name).TargetType():lower()
		if id == mq.TLO.Me.ID() and target_type == 'self' or target_type:sub(1, 5) == 'group' then
			target_id = 0
		end
		if mq.TLO.Spell(buff_name).Category():lower() == 'auras' then
			LastAura = buff_name
			if MyClass.IsBard then
				actionqueue.AddUnique(
					ScpBardCastAura(
						buff_name,
						'gem' .. gem
					)
				)
			else
				actionqueue.AddUnique(
					ScpCast(
						buff_name,
						'gem' .. gem,
						Config:Buff():MinMana(),
						1,
						target_id,
						0,
						nil,
						priority
					)
				)
			end
		else
			actionqueue.AddUnique(
				ScpCast(
					buff_name,
					'gem' .. gem,
					Config:Buff():MinMana(),
					1,
					target_id,
					0,
					nil,
					priority
				)
			)
		end
	end
end

local function CheckOnBuffsForId(package, target_id, char_name, key_order)
	for i, spell_key in ipairs(package) do
		local spell = Config:Spells():Spell(spell_key)
		if spell.Type == 'item' then
			local ready = mq.TLO.Me.ItemReady(spell.Name)()
			if ready and not HasBuff(spell.Effect, target_id) then
				actionqueue.AddUnique(
					ScpCast(
						spell.Name,
						spell.Type,
						0,
						1,
						target_id,
						0,
						nil,
						89
					)
				)
			end
		elseif spell.Type == 'alt' then
			local ready = mq.TLO.Me.AltAbilityReady(spell.Name)()
			if ready and not HasBuff(spell.Effect, target_id) then
				actionqueue.AddUnique(
					ScpCast(
						spell.Name,
						spell.Type,
						0,
						1,
						target_id,
						0,
						nil,
						89
					)
				)
			end
		else
			local gem, err = Config:SpellBar():GemBySpell(spell)
			if gem < 0 then
				log(err)
			else
				--print(char_name .. ':' .. tostring(sHasBuff(spell_name, target_id)))
				if not excepted(spell.Name, target_id) and not HasBuff(spell.Name, target_id) then
					if gem ~= 0 then
						CastBuffOn(spell.Name, gem, target_id, char_name, common.TableIndexOf(key_order, spell_key))
					else
						if MyClass.IsBard then
							CastBuffOn(spell.Name, 1, target_id, char_name, common.TableIndexOf(key_order, spell_key))
						else
							log(err)
						end
					end
				end
			end
		end
	end
end

local function copy_unique_into(into, from)
	for _, key in ipairs(from) do
		if not common.ArrayHasValue(into, key) then
			table.insert(into, key)
		end
	end
end

local function active_package_names()
	local names = { 'Self' }
	if mq.TLO.Pet() ~= 'NO PET' then table.insert(names, 'Selfpet') end
	if mq.TLO.Group.MainTank() ~= nil then table.insert(names, 'MainTank') end
	if mq.TLO.Group.MainAssist() ~= nil then table.insert(names, 'MainAssist') end
	if mq.TLO.Group.Puller() ~= nil then table.insert(names, 'Puller') end
	if mq.TLO.Group.Leader() ~= nil then table.insert(names, 'Leader') end
	if mq.TLO.Group.MarkNpc() ~= nil then table.insert(names, 'MarkNpc') end
	if mq.TLO.Group.MasterLooter() ~= nil then table.insert(names, 'MasterLooter') end
	for i=0, mq.TLO.Group.Members() do
		local class = EQClass:new(mq.TLO.Group.Member(i).Class.Name())
		if class.IsCaster then
			table.insert(names, 'Caster')
		end
		if class.IsHealer then
			table.insert(names, 'Healer')
		end
		if class.IsHybrid then
			table.insert(names, 'Hybrid')
		end
		table.insert(names, class.Name)
		table.insert(names, mq.TLO.Group.Member(i).Name())

		if i ~= 0 and class.HasPet then
			local pet_id = group.PetIdById(mq.TLO.Group.Member(i).ID())
			if pet_id ~= 0 then
				table.insert(names, 'Pet')
			end
		end
	end
	return names
end

local function ActiveSpellKeys()
	local keys = {}
	local names = active_package_names()
	for i, name in ipairs(names) do
		local package = Config:Buff():PackageByName(name)
		for j, key in ipairs(package) do
			if not common.ArrayHasValue(keys, key) then
				table.insert(keys, key)
			end
		end
	end
	return keys
end

local function group_member_class(idx)
	if idx == 0 then
		return MyClass
	end
	return EQClass:new(mq.TLO.Group.Member(idx).Class.Name())
end

local function group_member_name(idx)
	if idx == 0 then
		return mq.TLO.Me.Name()
	end
	return mq.TLO.Group.Member(idx).Name()
end

local function do_buffs()
	local active_keys = ActiveSpellKeys()

	for i=0, mq.TLO.Group.Members() do
		local member_name = group_member_name(i)
		local package = {}
		local id = group.MemberId(i)
		if id == mq.TLO.Me.ID() then
			copy_unique_into(package, Config:Buff():PackageByName('Self'))
		end
		if id == mq.TLO.Group.MainTank.ID() then
			copy_unique_into(package, Config:Buff():PackageByName('MainTank'))
		end
		if id == mq.TLO.Group.MainAssist.ID() then
			copy_unique_into(package, Config:Buff():PackageByName('MainAssist'))
		end
		if id == mq.TLO.Group.Puller.ID() then
			copy_unique_into(package, Config:Buff():PackageByName('Puller'))
		end
		if id == mq.TLO.Group.Leader.ID() then
			copy_unique_into(package, Config:Buff():PackageByName('Leader'))
		end
		if id == mq.TLO.Group.MarkNpc.ID() then
			copy_unique_into(package, Config:Buff():PackageByName('MarkNpc'))
		end
		if id == mq.TLO.Group.MasterLooter.ID() then
			copy_unique_into(package, Config:Buff():PackageByName('MasterLooter'))
		end
		local class = group_member_class(i)
		if class.IsCaster then
			copy_unique_into(package, Config:Buff():PackageByName('Caster'))
		end
		if class.IsHealer then
			copy_unique_into(package, Config:Buff():PackageByName('Healer'))
		end
		if class.IsMelee then
			copy_unique_into(package, Config:Buff():PackageByName('Melee'))
		end
		if class.IsHybrid then
			copy_unique_into(package, Config:Buff():PackageByName('Hybrid'))
		end
		copy_unique_into(package, Config:Buff():PackageByName(class.Name))
		copy_unique_into(package, Config:Buff():PackageByName(member_name))

		CheckOnBuffsForId(package, id, member_name, active_keys)

		if class.HasPet then
			if id == mq.TLO.Me.ID() and mq.TLO.Pet() ~= 'NO PET' then
				CheckOnBuffsForId(Config:Buff():PackageByName('Selfpet'), mq.TLO.Pet.ID(), 'my pet', active_keys)
			else
				local pet_id = group.PetIdById(id)
				if pet_id ~= 0 then
					CheckOnBuffsForId(Config:Buff():PackageByName('Pet'), pet_id, member_name .. '\'s pet', active_keys)
				end
			end
		end
	end
end


--
-- Event Handlers
--

local function exception1(line, spell_name)
	if Config:Buff():Backoff() then
		log('Exception: ' .. spell_name)
		local target_id = mq.TLO.Me.ID()
		if not Exceptions[target_id] then
			Exceptions[target_id] = {}
		end
		Exceptions[target_id][spell_name] = mq.gettime()
	end
end

local function exception2(line, spell_name, target_name)
	if Config:Buff():Backoff() then
		log('Exception: ' .. spell_name .. ' on ' .. target_name)
		local target_id = mq.TLO.Spawn(target_name).ID()
		if not Exceptions[target_id] then
			Exceptions[target_id] = {}
		end
		Exceptions[target_id][spell_name] = mq.gettime()
	end
end

local function exception3(line)
	if Config:Buff():Backoff() then
		log('Exception: ' .. LastAura)
		local id = mq.TLO.Me.ID()
		if not Exceptions[id] then
			Exceptions[id] = {}
		end
		Exceptions[id][LastAura] = mq.gettime()
	end
end


--
-- Init
--

function buffbot.Init(state, cfg, aq)
	State = state
	Config = cfg
	actionqueue = aq

	mq.event('exception1', 'Your #1# spell did not take hold.#*#', exception1)
	mq.event('exception2', 'Your #1# spell did not take hold on #2#.#*#', exception2)
	mq.event('exception3', 'You do not have sufficient focus to maintain that ability.', exception3)
end


---
--- Main Loop
---

function buffbot.Run()
	log('Up and running')
	while true do
		---@diagnostic disable-next-line: undefined-field
		if not mychar.InCombat() and not State.IsEarlyCombatActive then
			do_buffs()
		end
		co.delay(1000)
	end
end

return buffbot