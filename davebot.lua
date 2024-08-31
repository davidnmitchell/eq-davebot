local mq = require('mq')
local lua = require('lua')
local mychar = require('mychar')
local spells = require('spells')
local heartbeat = require('heartbeat')
require('ini')
require('eqclass')
require('botstate')
require('autosit')


--
-- Globals
--

local MyClass = EQClass:new()
local State = BotState:new(true, 'davebot', false, false)
local Autosit = AutoSit:new(State)

local Running = true
local LastHeardFrom = {}


--
-- Functions
--

local function CheckBot(name)
	local timeout = 15000
	if name == 'buffbot' then timeout = 20000 end
	if heartbeat.CheckProcess(name, LastHeardFrom[name], timeout) then
		LastHeardFrom[name] = mq.gettime()
	end
end

--
-- Main
--
-- TODO: Key off of MainAssist instead of MainTank
-- TODO: Individual class spell lists/abilities (scan Book and write to ini?)
-- TODO: Test multiple coroutines with mq.delay to see if it holds up all threads in a process or not
-- TODO: Warn when MainTank/MainAssist not set (idles most offense routines and does not say anyting about it)
-- TODO: Pre-mem spells (done for Bard)
-- TODO: Check for a more powerful buff before buffing (see autotoon)
-- TODO: Replace camp plugin (see autotoon)
-- TODO: Immunity/resist memory by mob name/type (save to ini?)
-- TODO: Pre-populated spells in configs
-- TODO: Summon food/drink (MQ2FeedMe?)
-- TODO: Stuns
-- TODO: AoE
-- TODO: Charms
-- TODO: Handle zoning better (see autotoon)
-- TODO: Autoload any missing plugins
-- TODO: Short lived combat buffs
-- TODO: Cure detrimental effects (target datatype)
-- TODO: Finding and pulling (see autotoon)
-- TODO: MQ2NetBots (replace pet buffs with, maybe other uses)
-- TODO: Item Buffs
-- TODO: Lose aggro logic
-- TODO: Have all CC members communicate
-- TODO: /setwintitle, /foreground /setprio
-- TODO: Loot
-- TODO: GUI? (see autotoon)
-- TODO: Change modes 5,6,7,8,9 to just 5? with flags for each mode instead
-- TODO: WIP Modes: 1 - Manual, 2 - Managed 3 - Managed IC 4 - Camped 5 - Camped IC 6 - Travel 7 - Travel IC

local function main()
	local last_spell_count = 0

	mq.cmd('/setwintitle ' .. mq.TLO.Me.Name())

	mq.bind(
		'/db',
		function(...)
			local args = { ... }
			if args[1] == 'shutdown' then
				lua.KillScriptIfRunning('gembot')
				lua.KillScriptIfRunning('castqueue')
				lua.KillScriptIfRunning('dotbot')
				lua.KillScriptIfRunning('nukebot')
				lua.KillScriptIfRunning('buffbot')
				lua.KillScriptIfRunning('healbot')
				lua.KillScriptIfRunning('crowdcontrolbot')
				lua.KillScriptIfRunning('debuffbot')
				lua.KillScriptIfRunning('petbot')
				lua.KillScriptIfRunning('songbot')
				lua.KillScriptIfRunning('meleebot')
				mq.exit()
			end
		end
	)
	mq.bind(
		'/dbhb',
		function(...)
			local args = { ... }
			LastHeardFrom[args[1]] = mq.gettime()
		end
	)

	print('davebot loaded')
	while Running == true do
		mq.doevents()

		if MyClass.HasSpells or MyClass.IsBard then
			local spell_count = spells.KnownSpellCount()
			if spell_count > last_spell_count then
				last_spell_count = spell_count
				local ini = Ini:new()
				spells.DumpSpellBook(ini, 'Spells')
			end

			CheckBot('gembot')
		end

		if MyClass.HasSpells then
			CheckBot('castqueue')
			CheckBot('dotbot')
			CheckBot('nukebot')
		end

		CheckBot('buffbot')

		if MyClass.IsHealer or MyClass.Name == 'Shadow Knight' then
			CheckBot('healbot')
		end

		if MyClass.IsCrowdController then
			CheckBot('crowdcontrolbot')
		end

		if MyClass.IsDebuffer then
			CheckBot('debuffbot')
		end

		if MyClass.HasPet then
			CheckBot('petbot')
		end

		if MyClass.IsBard then
			CheckBot('songbot')
		end

		if MyClass.IsMelee then
			CheckBot('meleebot')
		end

		Autosit:Check()

		mq.delay(1)
	end
end


--
-- Execution
--

main()
