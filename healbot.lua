local mq = require('mq')
local co = require('co')
local mychar = require('mychar')
require('eqclass')
require('actions.s_cast')
require('actions.s_castheal')
require('actions.s_lifetap')
local common = require('common')


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
	print('(healbot) ' .. tostring(msg))
end

local function ClassAtHpPct(class)
	if class.IsCaster or class.IsHealer then
		return Config.Heal.CasterAtHpPct()
	else
		return Config.Heal.MeleeAtHpPct()
	end
end

local function LowestHPsGroupMember()
	local groupSize = mq.TLO.Group.Members()
	local lowestMember = {id=0, hps=101}
	for i=0,groupSize do
		local pct_hps = mq.TLO.Group.Member(i).PctHPs()
		if pct_hps ~= nil then
			local class = EQClass:new(mq.TLO.Group.Member(i).Class.Name())
			local h = ClassAtHpPct(class)
			if pct_hps < lowestMember.hps and pct_hps <= h.pct then
				lowestMember = {
					id=mq.TLO.Group.Member(i).ID(),
					name=mq.TLO.Group.Member(i).Name(),
					idx=i,
					hps=pct_hps,
					threshold=h.pct,
					class=class,
					spell_key=h.key
				}
			end
		end
	end
	return lowestMember
end

local function CheckTank()
	local h = Config.Heal.TankAtHpPct()
	if h.pct ~= 0 then
		if mq.TLO.Group.MainTank() ~= nil then
			local pct_hps = mq.TLO.Group.MainTank.PctHPs()
			if pct_hps ~= nil and pct_hps <= h.pct then
				local castable = Config.Spells.Spell(h.key)
				local res = Config.SpellBar.GemBySpell(castable)
				if res.gem < 1 then
					log(res.msg)
				else
					actionqueue.AddUnique(
						ScpCastHeal(
							castable,
							'gem' .. res.gem,
							Config.Heal.MinMana(),
							mq.TLO.Group.MainTank.ID(),
							h.pct,
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
		local castable = Config.Spells.Spell(to_heal.spell_key)
		local res = Config.SpellBar.GemBySpell(castable)
		if res.gem < 1 then
			log(res.msg)
		else
			actionqueue.AddUnique(
				ScpCastHeal(
					castable,
					'gem' .. res.gem,
					Config.Heal.MinMana(),
					to_heal.id,
					to_heal.threshold,
					30
				)
			)
		end
	end
end

local function GroupHeal(pct, spell_key)
	local castable = Config.Spells.Spell(spell_key)
	local res = Config.SpellBar.GemBySpell(spell_key)
	if res.gem < 1 then
		log(res.msg)
	else
		if mq.TLO.Me.CurrentMana() > mq.TLO.Spell(castable.Name).Mana() then
			actionqueue.AddUnique(
				ScpCast(
					castable,
					'gem' .. res.gem,
					Config.Heal.MinMana(),
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
	local h = Config.Heal.PetAtHpPct()
	if h.pct ~= 0 then
		local group_size = mq.TLO.Group.Members()
		for i=0,group_size do
			if not mq.TLO.Group.Member(i).Pet() == nil then
				if mq.TLO.Group.Member(i).Pet.PctHPs() < h.pct then
					local castable = Config.Spells.Spell(h.key)
					local res = Config.SpellBar.GemBySpell(castable)
					if res.gem < 1 then
						log(res.msg)
					else
						actionqueue.AddUnique(
							ScpCastHeal(
								castable,
								'gem' .. res.gem,
								Config.Heal.MinMana(),
								mq.TLO.Group.Member(i).Pet.ID(),
								h.pct,
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
	local h = Config.Heal.SelfAtHpPct()
	if h.pct ~= 0 then
		local pct_hps = mq.TLO.Me.PctHPs()
		if pct_hps ~= nil and pct_hps <= h.pct then
			local castable = Config.Spells.Spell(h.key)
			local res = Config.SpellBar.GemBySpell(castable)
			if res.gem < 1 then
				log(res.msg)
			else
				local spell_target = mq.TLO.Spell(castable.Name).TargetType()
				if spell_target == 'LifeTap' then
					local target_id = mq.TLO.Target.ID() or 0
					if mychar.InCombat() and target_id ~= 0 and mq.TLO.Spawn(target_id).Type() == 'NPC' then
						actionqueue.AddUnique(
							ScpLifetap(
								castable.Name,
								'gem' .. res.gem,
								Config.Heal.MinMana(),
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
						ScpCastHeal(
							castable,
							'gem' .. res.gem,
							Config.Heal.MinMana(),
							mq.TLO.Me.ID(),
							h.pct,
							30
						)
					)
				end
			end
		end
	end
end

local function CheckMyPet()
	local h = Config.Heal.SelfpetAtHpPct()
	if h.pct ~= 0 then
		local pct_hps = mq.TLO.Pet.PctHPs()
		if pct_hps and pct_hps <= h.pct then
			local castable = Config.Spells.Spell(h.key)
			local res = Config.SpellBar.GemBySpell(castable)
			if res.gem < 1 then
				log(res.msg)
			else
				actionqueue.AddUnique(
					ScpCastHeal(
						castable.Name,
						'gem' .. res.gem,
						Config.Heal.MinMana(),
						mq.TLO.Pet.ID(),
						h.pct,
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
			local h = Config.Heal.GroupAtHpPct()
			if mq.TLO.Group.Injured(h.pct)() > 2 then
				GroupHeal(h.pct, h.key)
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