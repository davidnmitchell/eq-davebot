local mq = require('mq')
require('ini')
require('botstate')
require('eqclass')
local str = require('str')
local spells = require('spells')
local target = require('target')
local common = require('common')


--
-- Globals
--

MyClass = EQClass:new()
State = BotState:new('dotbot', true, false)

Running = true
Enabled = true

Spells = {}
Groups = {}


--
-- Functions
--

function BuildIni(ini)
	print('Building dot config')

	local dot_options = ini:Section('Dot Options')
	dot_options:WriteBoolean('Enabled', false)
	dot_options:WriteNumber('DefaultMinMana', 30)
	dot_options:WriteNumber('DefaultMinTargetHpPct', 50)

	local dot_spells = ini:Section('Dot Spells')
	dot_spells:WriteString('mag', 'Damage Over Time,Magic,Single')

	local dot_group_1 = ini:Section('Dot Group 1')
	dot_group_1:WriteString('Modes', '5,6,7,8,9')

	local dot_gems_1 = ini:Section('Dot Gems 1')
	dot_gems_1:WriteNumber('mag', 2)

	local dot_cast_at_pct_1 = ini:Section('Dot Cast At Percent 1')
	dot_cast_at_pct_1:WriteNumber('mag', 85)
end

function LoadIni(ini)
	Enabled = ini:Boolean('Dot Options', 'Enabled', false)
	local default_gem = ini:Number('Dot Options', 'DefaultGem', 6)
	local default_min_mana = ini:Number('Dot Options', 'DefaultMinMana', 45)
	local default_min_target_hp_pct = ini:Number('Dot Options', 'DefaultMinTargetHpPct', 50)

	Spells = ini:SectionToTable('Dot Spells')

	local i = 1
	while ini:HasSection('Dot Group ' .. i) do
		local group = ini:SectionToTable('Dot Group ' .. i)
		local modes = str.Split(group['Modes'], ',')
		common.TableValueToNumberOrDefault(group, 'DefaultGem', default_gem)
		common.TableValueToNumberOrDefault(group, 'MinMana', default_min_mana)
		common.TableValueToNumberOrDefault(group, 'MinTargetHpPct', default_min_target_hp_pct)
		group['Gems'] = ini:SectionToTable('Dot Gems ' .. i)
		group['AtPcts'] = ini:SectionToTable('Dot Cast At Percent ' .. i)
		for idx,mode in ipairs(modes) do
			Groups[tonumber(mode)] = group
		end
		i = i + 1
	end

	return i - 1
end

function Setup()
	local ini = Ini:new()

	if ini:IsMissing('Dot Options', 'Enabled') then BuildIni(ini) end

	local groups = LoadIni(ini)

	print('Dotbot loaded with ' .. groups .. ' groups')

	return ini
end

function HasDot(dot_name, id)
	return mq.TLO.Spawn(id).Buff(dot_name)() ~= nil
end

function CastDotOn(spell_name, gem, id)
	local name = mq.TLO.Spell(spell_name).Name()
	if name then
		spells.QueueSpellIfNotQueued(name, 'gem' .. gem, id, 'Dotting ' .. mq.TLO.Spawn(id).Name() .. ' with ' .. spell_name, Groups[State.Mode].MinMana, Groups[State.Mode].MinTargetHpPct, 2, 6)
	end
end

function CheckDots()
	for id,spell in pairs(Spells) do
		local name = spells.ReferenceSpell(spell)
		if not name then
			print('Could not find anything for ' .. spell)
		end
		local gem = Groups[State.Mode].Gems[id]
		if gem == nil then
			gem = Groups[State.Mode].DefaultGem
		end
		local pct = tonumber(Groups[State.Mode].AtPcts[id])
		if pct ~= nil then
			local group_target_id = mq.TLO.Me.GroupAssistTarget.ID()
			local group_target_name = mq.TLO.Me.GroupAssistTarget.Name()

			if group_target_id ~= nil and not target.IsInGroup(group_target_id) then
				local pct_hps = mq.TLO.Spawn(group_target_id).PctHPs()
				if pct_hps ~= nil and pct_hps < pct and pct_hps >= Groups[State.Mode].MinTargetHpPct and not HasDot(name, group_target_id) then
					CastDotOn(name, gem, group_target_id)
				end
			end
		end
	end
end


--
-- Main
--

local function main()
	local ini = Setup()
	local nextload = mq.gettime() + 10000

	while Running == true do
		mq.doevents()

		if Enabled and State.Mode == State.AutoCombatMode and not State.CrowdControlActive and mq.TLO.Me.GroupAssistTarget() ~= nil then
			CheckDots()
		end

		if State.Mode ~= State.AutoCombatMode and State.CrowdControlActive then
			State.CrowdControlActive = false
		end

		local time = mq.gettime()
		if time >= nextload then
			LoadIni(ini)
			nextload = time + 10000
		end
		mq.delay(10)
	end
end


--
-- Execution
--

main()
