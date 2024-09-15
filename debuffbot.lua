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

local ProcessName = 'debuffbot'
local MyClass = EQClass:new()
local Config = Config:new(ProcessName)

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

function CastDebuffOn(spell_name, gem, id, order)
	local priority = 40 + order
	local name = mq.TLO.Spell(spell_name).Name()
	if name then
		if not mq.TLO.Spawn(id).Buff(name).Name() then
			spells.QueueSpellIfNotQueued(
				name,
				'gem' .. gem,
				id,
				'Debuffing ' .. mq.TLO.Spawn(id).Name() .. ' with ' .. spell_name,
				Config:Debuff():MinMana(),
				Config:Debuff():MinTargetHpPct(),
				2,
				priority
			)
		end
	end
end

function CheckDebuffs()
	local i = 1
	for pct,spell_key in pairs(Config:Debuff():AtTargetHpPcts()) do
		local gem, spell_name, err = Config:SpellBar():GemAndSpellByKey(spell_key)
		if gem < 1 then
			log(err)
		else
			---@diagnostic disable-next-line: undefined-field
			local group_target_id = mq.TLO.Me.GroupAssistTarget.ID()
			local group_target_pct_hps = mq.TLO.Spawn(group_target_id).PctHPs()

			if group_target_id and not target.IsInGroup(group_target_id) and group_target_pct_hps and group_target_pct_hps < pct and group_target_pct_hps >= Config:Debuff():MinTargetHpPct() and not HasDebuff(spell_name, group_target_id) then
				CastDebuffOn(spell_name, gem, group_target_id, i)
			end
		end
		i = i + 1
	end
end


--
-- Main
--

local function main()
	if MyClass.IsDebuffer then
		while Running == true do
			mq.doevents()

			if Config:Debuff():Enabled() and mychar.InCombat() and not Config:State():CrowdControlActive() then
				CheckDebuffs()
			end

			if group.MainAssistCheck(60000) then
				log('Group main assist is not set')
			end

			Config:Reload(10000)

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
