local mq = require('mq')
require('ini')
require('eqclass')
require('botstate')
local str = require('str')
local spells = require('spells')
local mychar = require('mychar')
local common = require('common')


--
-- Globals
--

MyClass = EQClass:new()
State = BotState:new('debuffbot', true, false)

Running = true
Enabled = true

Spells = {}
Groups = {}


--
-- Functions
--

function BuildIni(ini)
	print('Building debuff config')

	local debuff_options = ini:Section('Debuff Options')
	debuff_options:WriteBoolean('Enabled', false)
	debuff_options:WriteNumber('DefaultMinMana', 45)
	debuff_options:WriteNumber('DefaultMinTargetHpPct', 50)

	local debuff_spells = ini:Section('Debuff Spells')
	debuff_spells:WriteString('cri', 'Disempower')
	debuff_spells:WriteString('res', 'Malaise')
	debuff_spells:WriteString('slo', 'Walking Sleep')

	local debuff_group_1 = ini:Section('Debuff Group 1')
	debuff_group_1:WriteString('Modes', '4,5,6')
	debuff_group_1:WriteNumber('MinMana', 20)
	debuff_group_1:WriteNumber('MinTargetHpPct', 8)

	local debuff_gems_1 = ini:Section('Debuff Gems 1')
	debuff_gems_1:WriteNumber('cri', 6)
	debuff_gems_1:WriteNumber('res', 7)
	debuff_gems_1:WriteNumber('slo', 8)

	local debuff_cast_at_pct_1 = ini:Section('Debuff Cast At Percent 1')
	debuff_cast_at_pct_1:WriteNumber('cri', 65)
	debuff_cast_at_pct_1:WriteNumber('res', 95)
	debuff_cast_at_pct_1:WriteNumber('slo', 90)

	local debuff_group_2 = ini:Section('Debuff Group 2')
	debuff_group_2:WriteString('Modes', '7,8,9')
	debuff_group_2:WriteNumber('MinMana', 20)
	debuff_group_2:WriteNumber('MinTargetHpPct', 8)

	local debuff_gems_2 = ini:Section('Debuff Gems 2')
	debuff_gems_2:WriteNumber('cri', 6)
	debuff_gems_2:WriteNumber('res', 7)
	debuff_gems_2:WriteNumber('slo', 8)

	local debuff_cast_at_pct_2 = ini:Section('Debuff Cast At Percent 2')
	debuff_cast_at_pct_2:WriteNumber('cri', 65)
	debuff_cast_at_pct_2:WriteNumber('res', 95)
	debuff_cast_at_pct_2:WriteNumber('slo', 90)
end

function Setup()
	local ini = Ini:new()

	if ini:IsMissing('Debuff Options', 'Enabled') then BuildIni(ini) end

	Enabled = ini:Boolean('Debuff Options', 'Enabled', false)
	local default_gem = ini:Number('Debuff Options', 'DefaultGem', 6)
	local default_min_mana = ini:Number('Debuff Options', 'DefaultMinMana', 45)
	local default_min_target_hp_pct = ini:Number('Debuff Options', 'DefaultMinTargetHpPct', 50)

	Spells = ini:SectionToTable('Debuff Spells')

	local i = 1
	while ini:HasSection('Debuff Group ' .. i) do
		local group = ini:SectionToTable('Debuff Group ' .. i)
		local modes = str.Split(group['Modes'], ',')
		common.TableValueToNumberOrDefault(group, 'DefaultGem', default_gem)
		common.TableValueToNumberOrDefault(group, 'MinMana', default_min_mana)
		common.TableValueToNumberOrDefault(group, 'MinTargetHpPct', default_min_target_hp_pct)
		group['Gems'] = ini:SectionToTable('Debuff Gems ' .. i)
		group['AtPcts'] = ini:SectionToTable('Debuff Cast At Percent ' .. i)
		for idx,mode in ipairs(modes) do
			Groups[tonumber(mode)] = group
		end
		i = i + 1
	end

	print('Debuffbot loaded with ' .. (i-1) .. ' groups')
end

function HasDebuff(debuff_name, id)
	return mq.TLO.Spawn(id).Buff(debuff_name)() ~= nil
end

function CastDebuffOn(spell_name, gem, id)
	local name = mq.TLO.Spell(spell_name).Name()
	if name then
		if not mq.TLO.Spawn(id).Buff(name).Name() then
			spells.QueueSpellIfNotQueued(name, 'gem' .. gem, id, 'Debuffing ' .. mq.TLO.Spawn(id).Name() .. ' with ' .. spell_name, Groups[State.Mode].MinMana, Groups[State.Mode].MinTargetHpPct, 2, 5)
		end
	end
end

function CheckDebuffs()
	if Groups[State.Mode] ~= nil then
		for id, spellref in pairs(Spells) do
			local spell = spells.ReferenceSpell(spellref)

			local gem = Groups[State.Mode].Gems[id]
			if gem == nil then
				gem = Groups[State.Mode].DefaultGem
			end
			local pct = tonumber(Groups[State.Mode].AtPcts[id])
			if pct ~= nil then
				local group_target_id = mq.TLO.Me.GroupAssistTarget.ID()
				local group_target_name = mq.TLO.Me.GroupAssistTarget.Name()
				local group_target_pct_hps = mq.TLO.Spawn(group_target_id).PctHPs()

				if group_target_pct_hps and group_target_pct_hps < pct and group_target_pct_hps >= Groups[State.Mode].MinTargetHpPct and not HasDebuff(spell, group_target_id) then
					CastDebuffOn(spell, gem, group_target_id)
				end
			end
		end
	end
end


--
-- Main
--

local function main()
	Setup()

	while Running == true do
		mq.doevents()

		if Enabled and (State.Mode == State.AutoCombatMode or mychar.InCombat()) and not State.CrowdControlActive then
			CheckDebuffs()
		end

		if State.CrowdControlActive and not mychar.InCombat() then
			State.CrowdControlActive = false
		end

		mq.delay(10)
	end
end


--
-- Execution
--

main()
