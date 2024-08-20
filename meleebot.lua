local mq = require('mq')
require('ini')
local spells = require('spells')
local mychar = require('mychar')


--
-- Globals
--

MyClass = EQClass:new()

Running = true
Enabled = true

EngageTargetHpPct = 95
EngageTargetDistance = 75

InCombat = false


--
-- Functions
--

function BuildIni(ini)
	print('Building melee config')

	local options = ini:Section('Melee Options')
	options:WriteBoolean('Enabled', false)
	options:WriteNumber('EngageTargetHpPct', 95)
	options:WriteNumber('EngageTargetDistance', 75)
end

function Setup()
	local ini = Ini:new()

	if ini:IsMissing('Melee Options', 'Enabled') then BuildIni(ini) end

	Enabled = ini:Boolean('Melee Options', 'Enabled', false)
	EngageTargetHpPct = ini:Number('Melee Options', 'EngageTargetHpPct', 95)
	EngageTargetDistance = ini:Number('Melee Options', 'EngageTargetDistance', 75)

	print('Melee config loaded')
end


--
-- Main
--

local function main()
	Setup()

	while Running == true do
		mq.doevents()

		if mychar.InCombat() and not InCombat then
			InCombat = true
			if MyClass.Name ~= 'Bard' then
				print('In combat, wiping spell queue')
				spells.WipeQueue()
			end
		end

		if not mychar.InCombat() and InCombat then
			InCombat = false
			if Enabled then
				mq.cmd('/makecamp return')
			end
		end
		
		if Enabled and mychar.InCombat() and not mq.TLO.Me.Combat() and mq.TLO.Me.GroupAssistTarget() then
			if mq.TLO.Me.GroupAssistTarget.PctHPs() < EngageTargetHpPct and mq.TLO.Me.GroupAssistTarget.Distance() < EngageTargetDistance then
				mq.cmd('/target ' .. mq.TLO.Me.GroupAssistTarget())
				mq.delay(250)
				mq.cmd('/stand')
				mq.cmd('/attack on')
			else
				--print('Waiting to engage')
			end
		end
		if Enabled and mychar.InCombat() and mq.TLO.Me.Combat() and (not mq.TLO.Target() or mq.TLO.Target() ~= mq.TLO.Me.GroupAssistTarget()) then
			mq.cmd('/attack off')
		end
		
		mq.delay(10)
	end
end


--
-- Execution
--

main()
