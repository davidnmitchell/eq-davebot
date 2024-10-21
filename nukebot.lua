local mq = require('mq')
local co = require('co')
local mychar = require('mychar')
require('actions.s_cast')


local nukebot = {}


--
-- Globals
--

local actionqueue = {}

local State = {}
local Config = {}
local History = {}


--
-- Functions
--

local function log(msg)
	print('(nukebot) ' .. msg)
end

local function CastNukeOn(spell_name, gem, id)
	actionqueue.Add(
		ScpCast(
			spell_name,
			'gem' .. gem,
			Config:Dd():MinMana(),
			2,
			id,
			Config:Dd():MinTargetHpPct(),
			nil,
			70
		)
	)
end

local function do_nukes()
	if mq.TLO.Me.GroupAssistTarget() then
		for pct,spell_key in pairs(Config:Dd():AtTargetHpPcts()) do
			local spell = Config:Spells():Spell(spell_key)
			local gem, err = Config:SpellBar():GemBySpell(spell)
			if gem < 1 then
				log(err)
			else
				---@diagnostic disable-next-line: undefined-field
				local group_target_id = mq.TLO.Me.GroupAssistTarget.ID()
				---@diagnostic disable-next-line: undefined-field
				local group_target_name = mq.TLO.Me.GroupAssistTarget.Name()

				if group_target_id then
					local pctHPs = mq.TLO.Spawn(group_target_id).PctHPs()
					if pctHPs and pctHPs < pct and not History['' .. spell.Name .. group_target_id .. group_target_name] then
						CastNukeOn(spell.Name, gem, group_target_id)
						History['' .. spell.Name .. group_target_id .. group_target_name] = true
					end
				end
			end
		end
	end
end


--
-- Init
--

function nukebot.Init(state, cfg, aq)
	State = state
	Config = cfg
	actionqueue = aq
end


---
--- Main Loop
---

function nukebot.Run()
	log('Up and running')
	while true do
		if State.Mode ~= 1 and mychar.InCombat() and not State.IsCrowdControlActive then
			do_nukes()
		end
		co.yield()
	end
end

return nukebot