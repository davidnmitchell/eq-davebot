local mq = require('mq')
local co = require('co')
local spells = require('spells')
local mychar = require('mychar')

local nukebot = {}


--
-- Globals
--

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
	spells.QueueSpell(State, spell_name, 'gem' .. gem, id, 'Nuking ' .. mq.TLO.Spawn(id).Name() .. ' with ' .. spell_name, Config:Dd():MinMana(), Config:Dd():MinTargetHpPct(), 2, 70)
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

function nukebot.Init(state, cfg)
	State = state
	Config = cfg
end


---
--- Main Loop
---

function nukebot.Run()
	log('Up and running')
	while true do
		if mychar.InCombat() and not State.IsCrowdControlActive then
			do_nukes()
		end
		co.yield()
	end
end

return nukebot