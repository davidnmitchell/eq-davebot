local mq = require('mq')
require('ini')
require('botstate')
local str = require('str')
local spells = require('spells')
local mychar = require('mychar')
local target = require('target')


--
-- Globals
--

MyClass = EQClass:new()
State = BotState:new('nukebot', true, false)

Running = true
Enabled = true

Spells = {}
Groups = {}

History = {}


--
-- Functions
--

function BuildIni(ini)
	print('Building nuke config')

	local options = ini:Section('Nuke Options')
	options.WriteBoolean('Enabled', false)
	options:WriteNumber('DefaultMinMana', 30)

	local nuke_spells = ini:Section('Nuke Spells')
	nuke_spells:WriteString('fire', 'Direct Damage,Fire,Single')

	local nuke_group_1 = ini:Section('Nuke Group 1')
	nuke_group_1:WriteString('Modes', '5,6,7,8,9')

	local nuke_gems_1 = ini:Section('Nuke Gems 1')
	nuke_gems_1:WriteNumber('fire', 3)

	local nuke_cast_at_pct_1 = ini:Section('Nuke Cast At Percent 1')
	nuke_cast_at_pct_1:WriteNumber('nuke', 85)
end

function Setup()
	local ini = Ini:new()

	if ini:IsMissing('Nuke Options', 'Enabled') then BuildIni(ini) end

	Enabled = ini:Boolean('Nuke Options', 'Enabled', false)
	local default_gem = ini:Number('Nuke Options', 'DefaultGem', 3)
	local default_min_mana = ini:Number('Nuke Options', 'DefaultMinMana', 45)

	Spells = ini:SectionToTable('Nuke Spells')

	local i = 1
	while ini:HasSection('Nuke Group ' .. i) do
		local group = ini:SectionToTable('Nuke Group ' .. i)
		local modes = str.Split(group['Modes'], ',')
		if group['DefaultGem'] == nil then group['DefaultGem'] = default_gem end
		if group['MinMana'] == nil then group['MinMana'] = default_min_mana end
		group['Gems'] = ini:SectionToTable('Nuke Gems ' .. i)
		group['AtPcts'] = ini:SectionToTable('Nuke Cast At Percent ' .. i)
		for idx,mode in ipairs(modes) do
			Groups[tonumber(mode)] = group
		end
		i = i + 1
	end

	print('Nukebot loaded with ' .. (i-1) .. ' groups')
end

function CastNukeOn(spell_name, gem, id)
	local name = mq.TLO.Spell(spell_name).Name()
	if name then
		spells.QueueSpell(name, 'gem' .. gem, id, 'Nuking ' .. mq.TLO.Spawn(id).Name() .. ' with ' .. spell_name, Groups[State.Mode].MinMana, 0, 2, 7)
	end
end

function CheckNukes()
	if mychar.InCombat() and mq.TLO.Me.GroupAssistTarget() then
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

				if group_target_id then
					local pctHPs = mq.TLO.Spawn(group_target_id).PctHPs()
					if pctHPs and pctHPs < pct and not History['' .. name .. group_target_id .. group_target_name] then
						CastNukeOn(name, gem, group_target_id)
						History['' .. name .. group_target_id .. group_target_name] = true
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
	Setup()

	while Running == true do
		mq.doevents()

		if mychar.InCombat() and not State.CrowdControlActive then
			CheckNukes()
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
