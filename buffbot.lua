local mq = require('mq')
local spells = require('spells')
local mychar = require('mychar')
local dannet = require('dannet')
local heartbeat = require('heartbeat')
require('eqclass')
require('botstate')
require('config')


--
-- Globals
--

local ProcessName = 'buffbot'
local MyClass = EQClass:new()
local State = BotState:new(false, ProcessName, false, false)
local Config = BuffConfig:new()
local Spells = SpellsConfig:new()
local SpellBar = SpellBarConfig:new()

local Running = true
local Exceptions = {}


--
-- Functions
--

local function log(msg)
	print('(' .. ProcessName .. ') ' .. msg)
end

local function Excepted(spell_name, target_id)
	return Exceptions[target_id] and Exceptions[target_id][spell_name] and Exceptions[target_id][spell_name] + Config:BackoffTimer(State) > mq.gettime()
end

function PeersPetHasBuff(buff_name, peer)
	local buff = dannet.Query(peer, 'Pet.Buff[' .. buff_name .. ']')
	return buff ~= 'NULL'
end

function HasAura(aura_name)
	---@diagnostic disable-next-line: missing-parameter
	return aura_name == mq.TLO.Me.Aura()
end

function HasBuff(spell_name, target_id)
	--if target_id == mq.TLO.Me.ID() then
	--	return mq.TLO.Me.Buff(spell_name)() == nil and not HasAura(spell_name)
	--else
		return mq.TLO.Spawn(target_id).Buff(spell_name)() ~= nil
	--end
end

function CastBuffOn(buff_name, gem, id, char_name)
	if mq.TLO.Spawn(id)() and mq.TLO.Spawn(id).Distance() <= mq.TLO.Spell(buff_name).Range() then
		spells.QueueSpellIfNotQueued(buff_name, 'gem' .. gem, id, 'Buffing ' .. char_name .. ' with ' .. buff_name, Config:MinMana(State), 0, 1, 9)
	end
end

function CheckOnBuffsForId(package, target_id, char_name)
	for i,spell_key in ipairs(package) do
		local gem, spell_name, err = SpellBar:GemAndSpellByKey(State, Spells, spell_key)
		if gem < 0 then
			log(err)
		else
			if not Excepted(spell_name, target_id) and not HasBuff(spell_name, target_id) then
				if gem ~= 0 then
					CastBuffOn(spell_name, gem, target_id, char_name)
				else
					if MyClass.IsBard then
						CastBuffOn(spell_name, 1, target_id, char_name)
					else
						log(err)
					end
				end
			end
		end
	end
end

function CheckOnBuffsForIdsPet(package, target_id, char_name)
	local peer = dannet.PeerById(target_id)
	if peer then
		for i, spell_key in ipairs(package) do
			local gem, spell_name, err = SpellBar:GemAndSpellByKey(State, Spells, spell_key)
			if gem < 1 then
				log(err)
			else
				if not Excepted(spell_name, target_id) and not PeersPetHasBuff(spell_name, peer) then
					CastBuffOn(spell_name, gem, mq.TLO.Spawn(target_id).Pet.ID(), char_name)
				end
			end
		end
	else
		CheckOnBuffsForId(package, mq.TLO.Spawn(target_id).Pet.ID(), char_name)
	end
end

function CheckOnBuffsForMe(package)
	return CheckOnBuffsForId(package, mq.TLO.Me.ID(), mq.TLO.Me.Name())
end

function CheckSelfBuffs()
	CheckOnBuffsForMe(Config:SelfPackage(State))
	CheckOnBuffsForId(Config:SelfpetPackage(State), mq.TLO.Me.Pet.ID(), mq.TLO.Me.Pet.Name())
end

function CheckGroupBuffs()
	local class_name = ''
	local group_size = mq.TLO.Group.Members()
	for i=1,group_size do
		if mq.TLO.Me.ID() ~= mq.TLO.Group.Member(i).ID() and not mq.TLO.Group.Member(i).Offline() then
			if mq.TLO.Group.Member(i).MainTank() then
				CheckOnBuffsForId(Config:TankPackage(State), mq.TLO.Group.Member(i).ID(), mq.TLO.Group.Member(i).Name())
			else
				class_name = mq.TLO.Group.Member(i).Class.Name()
				if class_name == 'Shaman' or class_name == 'Cleric' or class_name == 'Wizard' or class_name == 'Magician' or class_name == 'Enchanter' or class_name == 'Necromancer' or class_name == 'Druid' then
					CheckOnBuffsForId(Config:CasterPackage(State), mq.TLO.Group.Member(i).ID(), mq.TLO.Group.Member(i).Name())
				elseif class_name == 'Warrior' or class_name == 'Shadow Knight' or class_name == 'Paladin' or class_name == 'Ranger' or class_name == 'Rogue' or class_name == 'Bard' or class_name == 'Berserker' or class_name == 'Beastlord' or class_name == 'Monk' then
					CheckOnBuffsForId(Config:MeleePackage(State), mq.TLO.Group.Member(i).ID(), mq.TLO.Group.Member(i).Name())
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
				CheckOnBuffsForIdsPet(Config:PetPackage(State), id, mq.TLO.Group.Member(i).Name() .. '\'s Pet')
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


local function exception1(line, spell_name)
	if Config:Backoff(State) then
		log('Exception: ' .. spell_name)
		local target_id = mq.TLO.Me.ID()
		if not Exceptions[target_id] then
			Exceptions[target_id] = {}
		end
		Exceptions[target_id][spell_name] = mq.gettime()
	end
end

local function exception2(line, spell_name, target_name)
	if Config:Backoff(State) then
		log('Exception: ' .. spell_name .. ' on ' .. target_name)
		local target_id = mq.TLO.Spawn(target_name).ID()
		if not Exceptions[target_id] then
			Exceptions[target_id] = {}
		end
		Exceptions[target_id][spell_name] = mq.gettime()
	end
end

--
-- Main
--

local function main()
	mq.event('exception1', 'Your #1# spell did not take hold.#*#', exception1)
	mq.event('exception2', 'Your #1# spell did not take hold on #2#.#*#', exception2)

	while Running == true do
		mq.doevents()

		if Config:Enabled(State) and not mychar.InCombat() then
			CheckBuffs()
		end

		Config:Reload(10000)
		Spells:Reload(20000)
		SpellBar:Reload(10000)

		heartbeat.SendHeartBeat(ProcessName)
		mq.delay(10)
	end
end


--
-- Execution
--

main()
