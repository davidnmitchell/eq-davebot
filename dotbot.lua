local mq = require('mq')
local spells = require('spells')
local target = require('target')
local mychar = require('mychar')
local group = require('group')
local heartbeat = require('heartbeat')
require('eqclass')
require('config')


--
-- Globals
--

local ProcessName = 'dotbot'
local MyClass = EQClass:new()
local Config = Config:new(ProcessName)

local Running = true


--
-- Functions
--

local function log(msg)
	print('(' .. ProcessName .. ') ' .. msg)
end

function HasDot(dot_name, id)
	return mq.TLO.Spawn(id).Buff(dot_name)() ~= nil
end

function CastDotOn(spell_name, gem, id, order)
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

function CheckDots()
	local i = 1
	for pct, spell_key in pairs(Config:Dot():AtTargetHpPcts()) do
		local gem, spell_name, err = Config:SpellBar():GemAndSpellByKey(spell_key)
		if gem < 1 then
			log(err)
		else
			---@diagnostic disable-next-line: undefined-field
			local group_target_id = mq.TLO.Me.GroupAssistTarget.ID()
			local group_target_pct_hps = mq.TLO.Spawn(group_target_id).PctHPs()

			if group_target_id and not target.IsInGroup(group_target_id) and group_target_pct_hps and group_target_pct_hps < pct and group_target_pct_hps >= Config:Dot():MinTargetHpPct() and not HasDot(spell_name, group_target_id) then
				CastDotOn(spell_name, gem, group_target_id, i)
			end
		end
		i = i + 1
	end
end


--
-- Main
--

local function main()
	while Running == true do
		mq.doevents()

		if Config:Dot():Enabled() and mychar.InCombat() and not mq.TLO.DaveBot.States.IsCrowdControlActive() then
			CheckDots()
		end

		if group.MainAssistCheck(60000) then
			log('Group main assist is not set')
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
