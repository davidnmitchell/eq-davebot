local mq = require('mq')
local co = require('co')
require('eqclass')
require('actions.a_cast')
local mychar = require('mychar')


local healbot = {}


--
-- Globals
--

local actionqueue = {}

local State = {}
local Config = {}
local MyClass = EQClass:new()


--
-- Functions
--

local function log(msg)
	print('(healbot) ' .. msg)
end

local function ClassAtHpPct(class)
	if class.IsCaster or class.IsHealer then
		return Config:Heal():CasterAtHpPct()
	else
		return Config:Heal():MeleeAtHpPct()
	end
end

local function LowestHPsGroupMember()
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

local function CheckTank()
	local pct, spell_key = Config:Heal():TankAtHpPct()
	if pct ~= 0 then
		if mq.TLO.Group.MainTank() ~= nil then
			local pct_hps = mq.TLO.Group.MainTank.PctHPs()
			if pct_hps ~= nil and pct_hps <= pct then
				local spell = Config:Spells():Spell(spell_key)
				local gem, err = Config:SpellBar():GemBySpell(spell)
				if gem < 1 then
					log(err)
				else
					actionqueue.AddUnique(
						ScpCast(
							spell.Name,
							'gem' .. gem,
							Config:Heal():MinMana(),
							3,
							mq.TLO.Group.MainTank.ID(),
							0,
							nil,
							30
						)
					)
				end
			end
		end
	end
end

local function CheckGroupMembers()
	local to_heal = LowestHPsGroupMember()
	if to_heal.id ~= 0 then
		local spell = Config:Spells():Spell(to_heal.spell_key)
		local gem, err = Config:SpellBar():GemBySpell(spell)
		if gem < 1 then
			log(err)
		else
			actionqueue.AddUnique(
				ScpCast(
					spell.Name,
					'gem' .. gem,
					Config:Heal():MinMana(),
					3,
					to_heal.id,
					0,
					nil,
					30
				)
			)
		end
	end
end

local function GroupHeal(pct, spell_key)
	local spell = Config:Spells():Spell(spell_key)
	local gem, err = Config:SpellBar():GemBySpell(spell_key)
	if gem < 1 then
		log(err)
	else
		if mq.TLO.Me.CurrentMana() > mq.TLO.Spell(spell.Name).Mana() then
			actionqueue.AddUnique(
				ScpCast(
					spell.Name,
					'gem' .. gem,
					Config:Heal():MinMana(),
					3,
					mq.TLO.Me.ID(),
					0,
					nil,
					20
				)
			)
		end
	end
end

local function CheckPets()
	local pct, spell_key = Config:Heal():PetAtHpPct()
	if pct ~= 0 then
		local group_size = mq.TLO.Group.Members()
		for i=0,group_size do
			if not mq.TLO.Group.Member(i).Pet() == nil then
				if mq.TLO.Group.Member(i).Pet.PctHPs() < pct then
					local spell = Config:Spells():Spell(spell_key)
					local gem, err = Config:SpellBar():GemBySpell(spell_key)
					if gem < 1 then
						log(err)
					else
						actionqueue.AddUnique(
							ScpCast(
								spell.Name,
								'gem' .. gem,
								Config:Heal():MinMana(),
								1,
								mq.TLO.Group.Member(i).Pet.ID(),
								0,
								nil,
								60
							)
						)
					end
				end
			end
		end
	end
end

local function CheckSelf()
	local pct, spell_key = Config:Heal():SelfAtHpPct()
	if pct ~= 0 then
		local pct_hps = mq.TLO.Me.PctHPs()
		if pct_hps ~= nil and pct_hps <= pct then
			local spell = Config:Spells():Spell(spell_key)
			local gem, err = Config:SpellBar():GemBySpellKey(spell_key)
			if gem < 1 then
				log(err)
			else
				local spell_target = mq.TLO.Spell(spell.Name).TargetType()
				if spell_target == 'LifeTap' then
					local target_id = mq.TLO.Target.ID() or 0
					if mychar.InCombat() and target_id ~= 0 and mq.TLO.Spawn(target_id).Type() == 'NPC' then
						actionqueue.AddUnique(
							ScpCast(
								spell.Name,
								'gem' .. gem,
								Config:Heal():MinMana(),
								3,
								target_id,
								0,
								nil,
								30
							)
						)
					end
				else
					actionqueue.AddUnique(
						ScpCast(
							spell.Name,
							'gem' .. gem,
							Config:Heal():MinMana(),
							3,
							mq.TLO.Me.ID(),
							0,
							nil,
							30
						)
					)
				end
			end
		end
	end
end

local function CheckMyPet()
	local pct, spell_key = Config:Heal():SelfpetAtHpPct()
	if pct ~= 0 then
		local pct_hps = mq.TLO.Pet.PctHPs()
		if pct_hps and pct_hps <= pct then
			local spell = Config:Spells():Spell(spell_key)
			local gem, err = Config:SpellBar():GemBySpell(spell_key)
			if gem < 1 then
				log(err)
			else
				actionqueue.AddUnique(
					ScpCast(
						spell.Name,
						'gem' .. gem,
						Config:Heal():MinMana(),
						1,
						mq.TLO.Pet.ID(),
						0,
						nil,
						60
					)
				)
			end
		end
	end
end

local function CheckHitPoints()
	if mq.TLO.Group() then
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
	CheckSelf()
	if MyClass.HasPet then
		CheckMyPet()
	end
end


--
-- Init
--

function healbot.Init(state, cfg, aq)
	State = state
	Config = cfg
	actionqueue = aq
end


---
--- Main Loop
---

function healbot.Run()
	log('Up and running')
	while true do
		if State.Mode ~= 1 then
			CheckHitPoints()
		end
		co.yield()
	end
end

return healbot