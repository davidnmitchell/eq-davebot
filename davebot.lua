local mq = require('mq')
local lua = require('lua')
local mychar = require('mychar')
require('eqclass')
require('botstate')
require('autosit')


--
-- Globals
--

MyClass = EQClass:new()
State = BotState:new('davebot', false, false)

Running = true


--
-- Functions
--


local last_mode = State.Mode
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
-- TODO: Test multiple coroutines with mq.delay to see if it holds up all threads in a process or not
-- TODO: Pre-mem spells (done for Bard)
-- TODO: Immunity/resist memory (save to ini?)
-- TODO: Pre-populated spells in configs
-- TODO: Summon food/drink (MQ2FeedMe?)
-- TODO: Stuns
-- TODO: Short lived combat buffs
-- TODO: Cure detrimental effects (target datatype)
-- TODO: pulling
-- TODO: MQ2NetBots (replace pet buffs with, maybe other uses)
-- TODO: Item Buffs
-- TODO: Lose aggro logic
-- TODO: have all CC members communicate
-- TODO: Individual class spell lists/abilities
-- TODO: /setwintitle, /foreground /setprio

local function main()
	local autosit = Autosit:new()

	mq.cmd('/setwintitle ' .. mq.TLO.Me.Name())

	print('davebot loaded')
	while Running == true do
		mq.doevents()

		if MyClass.HasSpells then
			lua.RunScriptIfNotRunning('any_cast_queue')
			lua.RunScriptIfNotRunning('dotbot')
			lua.RunScriptIfNotRunning('nukebot')
		end

		lua.RunScriptIfNotRunning('buffbot')
		
		if MyClass.IsHealer or MyClass.Name == 'Shadow Knight' then
			lua.RunScriptIfNotRunning('healbot')
		end

		if MyClass.IsCrowdController then
			lua.RunScriptIfNotRunning('crowdcontrolbot')
		end

		if MyClass.IsDebuffer then
			lua.RunScriptIfNotRunning('debuffbot')
		end

		if MyClass.HasPet then
			lua.RunScriptIfNotRunning('petbot')
		end

		if MyClass.IsBard then
			lua.RunScriptIfNotRunning('songbot')
		end
		
		if MyClass.IsMelee then
			lua.RunScriptIfNotRunning('meleebot')
		else
			if mychar.InCombat() then
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
