local mq = require('mq')
local common = require('common')
local ini = require('ini')
local spells = require('spells')


--
-- Globals
--

Running = true
IniFilename = 'Bot_' .. mq.TLO.Me.CleanName() .. '.ini'

AutoMelee = false
EngageTargetHpPct = 95
EngageTargetDistance = 75

InCombat = false

MyClassName = mq.TLO.Me.Class.Name()


--
-- Functions
--

function BuildIni()
	print('Building melee config')
	
	mq.cmd('/ini "' .. IniFilename .. '" MeleeOptions AutoMelee FALSE')
	mq.cmd('/ini "' .. IniFilename .. '" MeleeOptions EngageTargetHpPct 95')
	mq.cmd('/ini "' .. IniFilename .. '" MeleeOptions EngageTargetDistance 75')
end

function Setup()
	if common.empty(IniFilename, 'MeleeOptions', 'AutoMelee') then BuildIni() end
	
	if not common.empty(IniFilename, 'MeleeOptions', 'AutoMelee') then AutoMelee = mq.TLO.Ini(IniFilename, 'MeleeOptions', 'AutoMelee')() == 'TRUE' end
	if not common.empty(IniFilename, 'MeleeOptions', 'EngageTargetHpPct') then EngageTargetHpPct = tonumber(mq.TLO.Ini(IniFilename, 'MeleeOptions', 'EngageTargetHpPct')()) end
	if not common.empty(IniFilename, 'MeleeOptions', 'EngageTargetDistance') then EngageTargetDistance = tonumber(mq.TLO.Ini(IniFilename, 'MeleeOptions', 'EngageTargetDistance')()) end
	
	print('Melee config loaded')
end


--
-- Main
--

function main()
	Setup()

	while Running == true do
		mq.doevents()

		if common.IsGroupInCombat() and not InCombat then
			InCombat = true
			if MyClassName ~= 'Bard' then
				print('In combat, wiping spell queue')
				spells.WipeQueue()
			end
		end

		if not common.IsGroupInCombat() and InCombat then
			InCombat = false
			if AutoMelee then
				mq.cmd('/makecamp return')
			end
		end
		
		if AutoMelee and common.IsGroupInCombat() and not mq.TLO.Me.Combat() and mq.TLO.Me.GroupAssistTarget() then
			if mq.TLO.Me.GroupAssistTarget.PctHPs() < EngageTargetHpPct and mq.TLO.Me.GroupAssistTarget.Distance() < EngageTargetDistance then
				mq.cmd('/target ' .. mq.TLO.Me.GroupAssistTarget())
				mq.delay(250)
				mq.cmd('/stand')
				mq.cmd('/attack on')
			else
				--print('Waiting to engage')
			end
		end
		if AutoMelee and common.IsGroupInCombat() and mq.TLO.Me.Combat() and (not mq.TLO.Target() or mq.TLO.Target() ~= mq.TLO.Me.GroupAssistTarget()) then
			mq.cmd('/attack off')
		end
		
		mq.delay(10)
	end
end


--
-- Execution
--

main()
