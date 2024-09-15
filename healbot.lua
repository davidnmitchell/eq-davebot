local mq = require('mq')
local spells = require('spells')
local heartbeat = require('heartbeat')
require('eqclass')
require('config')


--
-- Globals
--

local ProcessName = 'healbot'
local MyClass = EQClass:new()
local Config = Config:new(ProcessName)

local Running = true


--
-- Functions
--

local function log(msg)
	print('(' .. ProcessName .. ') ' .. msg)
end

local function ClassAtHpPct(class)
	if class.IsCaster or class.IsHealer then
		return Config:Heal():CasterAtHpPct()
	else
		return Config:Heal():MeleeAtHpPct()
	end
end

function LowestHPsGroupMember()
	local groupSize = mq.TLO.Group.Members()
	local lowestMember = {id=0, hps=101}
	for i=0,groupSize do
		local pct_hps = mq.TLO.Group.Member(i).PctHPs()
		if pct_hps ~= nil then
			local class = EQClass:new(mq.TLO.Group.Member(i).Class.Name())
			local pct, spell_key = ClassAtHpPct(class)
			if pct_hps < lowestMember.hps and pct_hps <= pct then
				lowestMember = {
					id=mq.TLO.Group.Member(i).ID(),
					name=mq.TLO.Group.Member(i).Name(),
					idx=i,
					hps=pct_hps,
					class=class,
					spell_key=spell_key
				}
			end
		end
	end
	return lowestMember
end

function CheckTank()
	local pct, spell_key = Config:Heal():TankAtHpPct()
	if pct ~= 0 then
		if mq.TLO.Group.MainTank() ~= nil then
			local pct_hps = mq.TLO.Group.MainTank.PctHPs()
			if pct_hps ~= nil and pct_hps <= pct then
				local gem, spell_name, err = Config:SpellBar():GemAndSpellByKey(spell_key)
				if gem < 1 then
					log(err)
				else
					spells.QueueSpellIfNotQueued(spell_name, 'gem' .. gem, mq.TLO.Group.MainTank.ID(), 'Healing ' .. mq.TLO.Group.MainTank.Name() .. ' with ' .. spell_name, 0, 0, 1, 30)
				end
			end
		else
			if not NoTankWarningPrinted then
				NoTankWarningPrinted = true
				log('No MainTank set in group')
			end
		end
	end
end

function CheckGroupMembers()
	local to_heal = LowestHPsGroupMember()
	if to_heal.id ~= 0 then
		local gem, spell_name, err = Config:SpellBar():GemAndSpellByKey(to_heal.spell_key)
		if gem < 1 then
			log(err)
		else
			spells.QueueSpellIfNotQueued(spell_name, 'gem' .. gem, to_heal.id, 'Healing ' .. to_heal.name .. ' with ' .. spell_name, 0, 0, 1, 30)
		end
	end
end

function GroupHeal(pct, spell_key)
	local gem, spell_name, err = Config:SpellBar():GemAndSpellByKey(spell_key)
	if gem < 1 then
		log(err)
	else
		if mq.TLO.Me.CurrentMana() > mq.TLO.Spell(spell_name).Mana() then
			spells.QueueSpellIfNotQueued(spell_name, 'gem' .. gem, mq.TLO.Me.ID(), 'Healing group with ' .. spell_name, 0, 0, 1, 20)
		end
	end
end

function CheckPets()
	local pct, spell_key = Config:Heal():PetAtHpPct()
	if pct ~= 0 then
		local group_size = mq.TLO.Group.Members()
		for i=0,group_size do
			if not mq.TLO.Group.Member(i).Pet() == nil then
				if mq.TLO.Group.Member(i).Pet.PctHPs() < pct then
					local gem, spell_name, err = Config:SpellBar():GemAndSpellByKey(spell_key)
					if gem < 1 then
						log(err)
					else
						spells.QueueSpellIfNotQueued(spell_name, 'gem' .. gem, mq.TLO.Group.Member(i).Pet.ID(), 'Healing ' .. mq.TLO.Group.Member(i).Name() .. '\'s pet with ' .. spell_name, 0, 0, 1, 60)
					end
				end
			end
		end
	end
end

function CheckSelf()
	local pct, spell_key = Config:Heal():SelfAtHpPct()
	if pct ~= 0 then
		local pct_hps = mq.TLO.Me.PctHPs()
		if pct_hps ~= nil and pct_hps <= pct then
			local gem, spell_name, err = Config:SpellBar():GemAndSpellByKey(spell_key)
			if gem < 1 then
				log(err)
			else
				local spell_target = mq.TLO.Spell(spell_name).TargetType()
				if spell_target == 'LifeTap' then
					if mq.TLO.Target() then
						spells.QueueSpellIfNotQueued(spell_name, 'gem' .. gem, mq.TLO.Target.ID(), 'Tapping ' .. mq.TLO.Target.Name() .. ' with ' .. spell_name, 0, 0, 1, 30)
					end
				else
					spells.QueueSpellIfNotQueued(spell_name, 'gem' .. gem, mq.TLO.Me.ID(), 'Healing ' .. mq.TLO.Me.Name() .. ' with ' .. spell_name, 0, 0, 1, 30)
				end
			end
		end
	end
end

function CheckMyPet()
	local pct, spell_key = Config:Heal():SelfpetAtHpPct()
	if pct ~= 0 then
		local pct_hps = mq.TLO.Pet.PctHPs()
		if pct_hps and pct_hps <= pct then
			local gem, spell_name, err = Config:SpellBar():GemAndSpellByKey(spell_key)
			if gem < 1 then
				log(err)
			else
				spells.QueueSpellIfNotQueued(spell_name, 'gem' .. gem, mq.TLO.Pet.ID(), 'Healing ' .. mq.TLO.Pet.Name() .. ' with ' .. spell_name, 0, 0, 1, 60)
			end
		end
	end
end

function CheckHitPoints()
	if MyClass.IsHealer and mq.TLO.Group() then
		CheckTank()

		if MyClass.HasGroupHeals then
			local pct, spell_key = Config:Heal():GroupAtHpPct()
			if mq.TLO.Group.Injured(pct)() > 2 then
				GroupHeal(pct, spell_key)
			end
		end

		if mq.TLO.Group.Injured(95)() > 0 then CheckGroupMembers() end

		CheckPets()
	end
	if not MyClass.IsHealer then
		CheckSelf()
		if MyClass.HasPet then
			CheckMyPet()
		end
	end
end


--
-- Main
--

local function main()
	if MyClass.IsHealer or MyClass.Name == 'Shadow Knight' then

		while Running == true do
			mq.doevents()

			CheckHitPoints()

			Config:Reload(10000)

			heartbeat.SendHeartBeat(ProcessName)
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
