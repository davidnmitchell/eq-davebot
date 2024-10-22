local mq = require('mq')
local co = require('co')
local target = require('target')
local mychar = require('mychar')
require('actions.a_cast')


local dotbot = {}


--
-- Globals
--

local actionqueue = {}

local State = {}
local Config = {}

local Exceptions = {}


--
-- Functions
--

local function log(msg)
	print('(dotbot) ' .. msg)
end

local function excepted(spell_name, mob_name)
	return (Exceptions[mob_name] and Exceptions[mob_name][spell_name]) or false
end

local function HasDot(spell, id)
	return mq.TLO.Spawn(id).Buff(spell.Effect)() ~= nil
end

local function CastDotOn(spell_name, gem, id, order)
	local priority = 50 + order
	if mq.TLO.Spell(spell_name).Name() then
		actionqueue.AddUnique(
			ScpCast(
				spell_name,
				'gem' .. gem,
				Config:Dot():MinMana(),
				2,
				id,
				Config:Dot():MinTargetHpPct(),
				nil,
				priority
			)
		)
	end
end

local function hps_are_in_range(id, pct)
	local hps = mq.TLO.Spawn(id).PctHPs()
	return hps and hps < pct and hps >= Config:Dot():MinTargetHpPct()
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

			if group_target_id and not target.IsInGroup(group_target_id) and hps_are_in_range(group_target_id, pct) and not HasDot(spell, group_target_id) then
				CastDotOn(spell.Name, gem, group_target_id, i)
			end
		end
		i = i + 1
	end
end


--
-- Event Handlers
--

local function exception1(line, spell_name, target_name)
	log('Exception: ' .. spell_name .. ' on ' .. target_name)
	local mob_name = mq.TLO.Spawn(target_name).CleanName()
	if not Exceptions[mob_name] then
		Exceptions[mob_name] = {}
	end
	Exceptions[mob_name][spell_name] = mq.gettime()
end


--
-- Init
--

function dotbot.Init(state, cfg, aq)
	State = state
	Config = cfg
	actionqueue = aq

	mq.event('dotbot_exception1', 'Your #1# spell did not take hold on #2#.#*#', exception1)
end


---
--- Main Loop
---

function dotbot.Run()
	log('Up and running')
	while true do
		if State.Mode ~= 1 and mychar.InCombat() and not State.IsCrowdControlActive then
			do_dots()
		end
		co.yield()
	end
end

return dotbot