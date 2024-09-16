local mq = require('mq')
local spells = require('spells')
local mychar = require('mychar')
local heartbeat = require('heartbeat')
require('eqclass')
require('config')


--
-- Globals
--

local ProcessName = 'nukebot'
local MyClass = EQClass:new()
local Config = Config:new(ProcessName)

local Running = true
local History = {}


--
-- Functions
--

local function log(msg)
	print('(' .. ProcessName .. ') ' .. msg)
end

function CastNukeOn(spell_name, gem, id)
	spells.QueueSpell(spell_name, 'gem' .. gem, id, 'Nuking ' .. mq.TLO.Spawn(id).Name() .. ' with ' .. spell_name, Config:Dd():MinMana(), Config:Dd():MinTargetHpPct(), 2, 70)
end

function CheckNukes()
	if mychar.InCombat() and mq.TLO.Me.GroupAssistTarget() then
		for pct,spell_key in pairs(Config:Dd():AtTargetHpPcts()) do
			local gem, spell_name, err = Config:SpellBar():GemAndSpellByKey(spell_key)
			if gem < 1 then
				log(err)
			else
				---@diagnostic disable-next-line: undefined-field
				local group_target_id = mq.TLO.Me.GroupAssistTarget.ID()
				---@diagnostic disable-next-line: undefined-field
				local group_target_name = mq.TLO.Me.GroupAssistTarget.Name()

				if group_target_id then
					local pctHPs = mq.TLO.Spawn(group_target_id).PctHPs()
					if pctHPs and pctHPs < pct and not History['' .. spell_name .. group_target_id .. group_target_name] then
						CastNukeOn(spell_name, gem, group_target_id)
						History['' .. spell_name .. group_target_id .. group_target_name] = true
					end
				end
			end
		end
	end
end


--
-- Main
--

local function main()
	while Running == true do
		mq.doevents()

		if Config:Dd():Enabled() and mychar.InCombat() and not mq.TLO.DaveBot.States.IsCrowdControlActive() then
			CheckNukes()
		end

		Config:Reload(10000)

		heartbeat.SendHeartBeat(ProcessName)
		mq.delay(10)
	end
end


--
-- Execution
--

main()
