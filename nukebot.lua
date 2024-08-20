local mq = require('mq')
local common = require('common')
local ini = require('ini')
local spells = require('spells')


--
-- Globals
--

Running = true
IniFilename = 'Bot_' .. mq.TLO.Me.CleanName() .. '.ini'

NukeSpells = {}
NukeGems = {}
NukePercents = {}

MinNukeMana = 30
DefaultNukeGem = 2	

History = {}
CrowdControlActive = false


--
-- Functions
--

function BuildIni()
	print('Building nuke config')
	
	mq.cmd('/ini "' .. IniFilename .. '" NukeOptions MinNukeMana 30')

	mq.cmd('/ini "' .. IniFilename .. '" "Nuke Spells" dot "Direct Damage,Fire,Single"')
	mq.cmd('/ini "' .. IniFilename .. '" "Nuke Spells" dd "Spirit Strike"')
	mq.cmd('/ini "' .. IniFilename .. '" "Nuke Spells" aoe "Poison Storm"')

	mq.cmd('/ini "' .. IniFilename .. '" "Nuke Gems" dot 2')
	mq.cmd('/ini "' .. IniFilename .. '" "Nuke Gems" dd 3')
	mq.cmd('/ini "' .. IniFilename .. '" "Nuke Gems" aoe 4')

	mq.cmd('/ini "' .. IniFilename .. '" "Nuke Cast At Percent" dot 95')
	mq.cmd('/ini "' .. IniFilename .. '" "Nuke Cast At Percent" dd 40')
end

function Setup()
	if common.empty(IniFilename, 'NukeOptions', 'MinNukeMana') then BuildIni() end
	
	if not common.empty(IniFilename, 'NukeOptions', 'MinNukeMana') then MinNukeMana = tonumber(mq.TLO.Ini(IniFilename, 'NukeOptions', 'MinNukeMana')()) end
	
	NukeSpells = ini.IniSectionToTable(IniFilename, 'Nuke Spells')
	NukeGems = ini.IniSectionToTable(IniFilename, 'Nuke Gems')
	NukePercents = ini.IniSectionToTable(IniFilename, 'Nuke Cast At Percent')
	
	print('Nuke config loaded')
end

function CastNukeOn(spellName, gem, id)
	name = mq.TLO.Spell(spellName).Name()
	if name then
		spells.QueueSpell(name, 'gem' .. gem, id, 'Nuking ' .. mq.TLO.Spawn(id).Name() .. ' with ' .. spellName, MinNukeMana, 0, 2, 7)
	end
end

function CheckNukes()
	if common.IsGroupInCombat() and mq.TLO.Me.GroupAssistTarget() then		
		for id,spell in pairs(NukeSpells) do
			local name = common.ReferenceSpell(spell)
			if not name then
				print('Could not find anything for ' .. spell)
			end
			local gem = NukeGems[id]
			if gem == nil then
				gem = DefaultNukeGem
			end
			local pct = tonumber(NukePercents[id])
			if pct ~= nil then
				local groupTargetId = mq.TLO.Me.GroupAssistTarget.ID()
				local groupTargetName = mq.TLO.Me.GroupAssistTarget.Name()

				if groupTargetId then
					local pctHPs = mq.TLO.Spawn(groupTargetId).PctHPs()
					if pctHPs and pctHPs < pct and not History['' .. name .. groupTargetId .. groupTargetName] then
						CastNukeOn(name, gem, groupTargetId)
						History['' .. name .. groupTargetId .. groupTargetName] = true
					end
				end			
			end
		end
	end
end


--
-- Events 
--

function notify_crowd_control_active(line)
	CrowdControlActive = true
end

function notify_crowd_control_inactive(line)
	CrowdControlActive = false
end


--
-- Main
--

function main()
	Setup()

	mq.event('ccactive', '#*#NOTIFY CCACTIVE', notify_crowd_control_active)
	mq.event('ccinactive', '#*#NOTIFY CCINACTIVE', notify_crowd_control_inactive)

	while Running == true do
		mq.doevents()

		if common.IsGroupInCombat() and not CrowdControlActive then
			CheckNukes()
		end
		
		if CrowdControlActive and not common.IsGroupInCombat() then
			CrowdControlActive = false
		end
		
		mq.delay(10)
	end
end


--
-- Execution
--

main()
