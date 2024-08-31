local mq = require('mq')
local spells = require('spells')
local target = require('target')
local mychar = require('mychar')
local group = require('group')
local heartbeat = require('heartbeat')
require('eqclass')
require('botstate')
require('config')


--
-- Globals
--

local ProcessName = 'debuffbot'
local MyClass = EQClass:new()
local State = BotState:new(false, ProcessName, true, false)
local Config = DebuffConfig:new()
local Spells = SpellsConfig:new()
local SpellBar = SpellBarConfig:new()

local Running = true


--
-- Functions
--

local function log(msg)
	print('(' .. ProcessName .. ') ' .. msg)
end

function HasDebuff(debuff_name, id)
	return mq.TLO.Spawn(id).Buff(debuff_name)() ~= nil
end

function CastDebuffOn(spell_name, gem, id)
	local name = mq.TLO.Spell(spell_name).Name()
	if name then
		if not mq.TLO.Spawn(id).Buff(name).Name() then
			spells.QueueSpellIfNotQueued(
				name,
				'gem' .. gem,
				id,
				'Debuffing ' .. mq.TLO.Spawn(id).Name() .. ' with ' .. spell_name,
				Config:MinMana(State),
				Config:MinTargetHpPct(State),
				2,
				5
			)
		end
	end
end

function CheckDebuffs()
	for pct,spell_key in pairs(Config:AtTargetHpPcts(State)) do
		local gem, spell_name, err = SpellBar:GemAndSpellByKey(State, Spells, spell_key)
		if gem < 1 then
			log(err)
		else
			---@diagnostic disable-next-line: undefined-field
			local group_target_id = mq.TLO.Me.GroupAssistTarget.ID()
			local group_target_pct_hps = mq.TLO.Spawn(group_target_id).PctHPs()

			if group_target_id and not target.IsInGroup(group_target_id) and group_target_pct_hps and group_target_pct_hps < pct and group_target_pct_hps >= Config:MinTargetHpPct(State) and not HasDebuff(spell_name, group_target_id) then
				CastDebuffOn(spell_name, gem, group_target_id)
			end
		end
	end
end


--
-- Main
--

local function main()
	if MyClass.IsDebuffer then
		while Running == true do
			mq.doevents()

			if Config:Enabled(State) and mychar.InCombat() and not State:CrowdControlActive() then
				CheckDebuffs()
			end

			if group.MainAssistCheck(60000) then
				log('Group main assist is not set')
			end

			Config:Reload(10000)
			Spells:Reload(20000)
			SpellBar:Reload(10000)

			heartbeat.SendHeartBeat(ProcessName)
			mq.delay(10)
		end
	else
		print('(debuffbot)No support for ' .. MyClass.Name)
		print('(debuffbot)Exiting...')
	end
end


--
-- Execution
--

main()
