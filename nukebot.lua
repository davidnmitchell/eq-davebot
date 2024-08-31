local mq = require('mq')
local spells = require('spells')
local mychar = require('mychar')
local heartbeat = require('heartbeat')
require('eqclass')
require('botstate')
require('config')


--
-- Globals
--

local ProcessName = 'nukebot'
local MyClass = EQClass:new()
local State = BotState:new(false, ProcessName, true, false)
local Config = DdConfig:new()
local Spells = SpellsConfig:new()
local SpellBar = SpellBarConfig:new()

local Running = true
local History = {}


--
-- Functions
--

local function log(msg)
	print('(' .. ProcessName .. ') ' .. msg)
end

function CastNukeOn(spell_name, gem, id)
	spells.QueueSpell(spell_name, 'gem' .. gem, id, 'Nuking ' .. mq.TLO.Spawn(id).Name() .. ' with ' .. spell_name, Config:MinMana(State), Config:MinTargetHpPct(State), 2, 7)
end

function CheckNukes()
	if mychar.InCombat() and mq.TLO.Me.GroupAssistTarget() then
		for pct,spell_key in pairs(Config:AtTargetHpPcts(State)) do
			local gem, spell_name, err = SpellBar:GemAndSpellByKey(State, Spells, spell_key)
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

		if Config:Enabled(State) and mychar.InCombat() and not State:CrowdControlActive() then
			CheckNukes()
		end

		Config:Reload()

		heartbeat.SendHeartBeat(ProcessName)
		mq.delay(10)
	end
end


--
-- Execution
--

main()
