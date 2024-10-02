local mq = require('mq')
local co = require('co')
local target = require('target')
local mychar = require('mychar')
require('actions.s_cast')


local debuffbot = {}


--
-- Globals
--

local actionqueue = {}

local State = {}
local Config = {}


--
-- Functions
--

local function log(msg)
	print('(debuffbot) ' .. msg)
end

local function HasDebuff(spell, id)
	return mq.TLO.Spawn(id).Buff(spell.Effect)() ~= nil
end

local function CastDebuffOn(spell_name, gem, id, order)
	assert(tonumber(gem))
	local priority = 40 + order
	if mq.TLO.Spell(spell_name).Name() then
		if not mq.TLO.Spawn(id).Buff(spell_name).Name() then
			actionqueue.AddUnique(
				ScpCast(
					spell_name,
					'gem' .. gem,
					Config:Debuff():MinMana(),
					2,
					id,
					Config:Debuff():MinTargetHpPct(),
					nil,
					priority
				)
			)
			-- spells.QueueSpellIfNotQueued(
			-- 	State,
			-- 	spell_name,
			-- 	'gem' .. gem,
			-- 	id,
			-- 	'Debuffing ' .. mq.TLO.Spawn(id).Name() .. ' with ' .. spell_name,
			-- 	Config:Debuff():MinMana(),
			-- 	Config:Debuff():MinTargetHpPct(),
			-- 	2,
			-- 	priority
			-- )
		end
	end
end

local function do_debuffs()
	local i = 1
	for pct,spell_key in pairs(Config:Debuff():AtTargetHpPcts()) do
		local spell = Config:Spells():Spell(spell_key)
		local gem, err = Config:SpellBar():GemBySpell(spell)
		if gem < 1 then
			log(err)
		else
			---@diagnostic disable-next-line: undefined-field
			local group_target_id = mq.TLO.Me.GroupAssistTarget.ID()
			local group_target_pct_hps = mq.TLO.Spawn(group_target_id).PctHPs()

			if group_target_id and not target.IsInGroup(group_target_id) and group_target_pct_hps and group_target_pct_hps < pct and group_target_pct_hps >= Config:Debuff():MinTargetHpPct() and not HasDebuff(spell, group_target_id) then
				CastDebuffOn(spell.Name, gem, group_target_id, i)
			end
		end
		i = i + 1
	end
end


--
-- Init
--

function debuffbot.Init(state, cfg, aq)
	State = state
	Config = cfg
	actionqueue = aq
end


---
--- Main Loop
---

function debuffbot.Run()
	log('Up and running')
	while true do
		if mychar.InCombat() and not State.IsCrowdControlActive then
			do_debuffs()
		end
		co.yield()
	end
end

return debuffbot