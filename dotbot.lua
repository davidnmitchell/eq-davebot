local mq = require('mq')
local co = require('co')
local spells = require('spells')
local target = require('target')
local mychar = require('mychar')


local dotbot = {}


--
-- Globals
--

local Config = {}


--
-- Functions
--

local function log(msg)
	print('(dotbot) ' .. msg)
end

local function HasDot(spell, id)
	return mq.TLO.Spawn(id).Buff(spell.Effect)() ~= nil
end

local function CastDotOn(spell_name, gem, id, order)
	local priority = 50 + order
	local name = mq.TLO.Spell(spell_name).Name()
	if name then
		if not mq.TLO.Spawn(id).Buff(name).Name() then
			spells.QueueSpellIfNotQueued(
				name,
				'gem' .. gem,
				id,
				'Dotting ' .. mq.TLO.Spawn(id).Name() .. ' with ' .. spell_name,
				Config:Dot():MinMana(),
				Config:Dot():MinTargetHpPct(),
				2,
				priority
			)
		end
	end
end

local function do_dots()
	local i = 1
	for pct, spell_key in pairs(Config:Dot():AtTargetHpPcts()) do
		local spell = Config:Spells():Spell(spell_key)
		local gem, err = Config:SpellBar():GemBySpell(spell)
		if gem < 1 then
			log(err)
		else
			---@diagnostic disable-next-line: undefined-field
			local group_target_id = mq.TLO.Me.GroupAssistTarget.ID()
			local group_target_pct_hps = mq.TLO.Spawn(group_target_id).PctHPs()

			if group_target_id and not target.IsInGroup(group_target_id) and group_target_pct_hps and group_target_pct_hps < pct and group_target_pct_hps >= Config:Dot():MinTargetHpPct() and not HasDot(spell, group_target_id) then
				CastDotOn(spell.Name, gem, group_target_id, i)
			end
		end
		i = i + 1
	end
end


--
-- Init
--

function dotbot.Init(cfg)
	Config = cfg
end


---
--- Main Loop
---

function dotbot.Run()
	log('Up and running')
	while true do
		---@diagnostic disable-next-line: undefined-field
		if mychar.InCombat() and not mq.TLO.DaveBot.States.IsCrowdControlActive() then
			do_dots()
		end
		co.yield()
	end
end

return dotbot