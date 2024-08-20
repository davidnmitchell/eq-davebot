local mq = require('mq')
local mychar = require('mychar')
require('eqclass')
require('botstate')
require('autosit')
local common = require('common')


--
-- Globals
--

Running = true
MyClass = EQClass:new()
State = BotState:new('davebot', false, false)


--
-- Functions
--


local last_mode = Mode
local in_combat = false
function CheckCombatMode()
	if mychar.InCombat() and not in_combat then
		in_combat = true
		last_mode = State.Mode
		mq.cmd('/echo NOTIFY BOTMODE ' .. State.AutoCombatMode)
	end
	if not mychar.InCombat() and in_combat then
		in_combat = false
		mq.cmd('/echo NOTIFY BOTMODE ' .. last_mode)
	end
end


--
-- Main
--
-- TODO: Reload config on file change
local function main()
	local autosit = Autosit:new()

	print('davebot loaded')
	while Running == true do
		mq.doevents()

		if MyClass.HasSpells then
			common.run_script_if_not_running('any_cast_queue')
			common.run_script_if_not_running('dotbot')
			common.run_script_if_not_running('nukebot')
		end

		common.run_script_if_not_running('buffbot')
		
		if MyClass.IsHealer then
			common.run_script_if_not_running('healbot')
		end

		if MyClass.IsCrowdController then
			common.run_script_if_not_running('crowdcontrolbot')
		end

		if MyClass.IsDebuffer then
			common.run_script_if_not_running('debuffbot')
		end

		if MyClass.HasPet then
			common.run_script_if_not_running('petbot')
		end

		if MyClass.IsBard then
			common.run_script_if_not_running('songbot')
		end
		
		if MyClass.IsMelee then
			common.run_script_if_not_running('meleebot')
		else
			if common.IsGroupInCombat() then
				--mq.cmd('/face')
			end
		end

		CheckCombatMode()
		autosit:Check()
		
		mq.delay(10)
	end
end


--
-- Execution
--

main()
