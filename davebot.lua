local mq = require('mq')
local co     = require('co')
local str    = require('str')
local spells = require('spells')
local lua = require('lua')
local heartbeat = require('heartbeat')
local bc     = require('bc')
require('eqclass')
require('config')
require('autositbot')
require('gembot')
local tlo = require('tlo')
local mychar = require('mychar')
local drivebot = require('drivebot')
local songbot = require('songbot')
local targetbot = require('targetbot')
local tetherbot = require('tetherbot')
local teameventbot = require('teameventbot')


--
-- Globals
--

local MyClass = EQClass:new()
local Config = Config:new('davebot')

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
-- TODO: Warn when MainTank/MainAssist not set (idles most offense routines and does not say anyting about it)
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
-- TODO: Item Buffs
-- TODO: Lose aggro logic
-- TODO: Have all CC members communicate
-- TODO: /setwintitle, /foreground /setprio
-- TODO: Loot
-- TODO: GUI? (see autotoon)

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
				Running = false
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

	bc.InitServer()

	tlo.Init(Config)
	local tlo_co = ManagedCoroutine:new(
		function()
			tlo.Run()
		end
	)
	teameventbot.Init(Config)
	local teameventbot_co = ManagedCoroutine:new(
		function()
			teameventbot.Run()
		end
	)
	drivebot.Init(Config)
	local drivebot_co = ManagedCoroutine:new(
		function()
			drivebot.Run()
		end
	)
	local autositbot_co = ManagedCoroutine:new(
		function()
			AutoSitBot:new(Config):Run()
		end
	)
	local gembot_co = ManagedCoroutine:new(
		function()
			GemBot:new(Config):Run()
		end
	)
	targetbot.Init(Config)
	local targetbot_co = ManagedCoroutine:new(
		function()
			targetbot.Run()
		end
	)
	tetherbot.Init(Config)
	local tetherbot_co = ManagedCoroutine:new(
		function()
			tetherbot.Run()
		end
	)
	if MyClass.IsBard then
		songbot.Init(Config)
	end
	local songbot_co = ManagedCoroutine:new(
		function()
			songbot.Run()
		end
	)
	local ecstate_co = ManagedCoroutine:new(
		function()
			while true do
				if mq.TLO.DaveBot.States.IsEarlyCombatActive() and not mychar.InCombat() and mq.TLO.DaveBot.States.EarlyCombatActiveSince() + 10000 < mq.gettime() then
					mq.TLO.DaveBot.States.EarlyCombatIsInactive()
				end
				co.yield()
			end
		end
	)

	print('DaveBot running')
	while Running == true do
		mq.doevents()

		tlo_co:Resume()
		teameventbot_co:Resume()
		drivebot_co:Resume()

		if MyClass.HasSpells or MyClass.IsBard then
			local spell_count = spells.KnownSpellCount()
			if spell_count > last_spell_count then
				last_spell_count = spell_count
				local ini = Ini:new()
				spells.DumpSpellBook(ini, 'Spells')
			end

			gembot_co:Resume()
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
			songbot_co:Resume()
		end

		if MyClass.IsMelee then
			CheckBot('meleebot')
		end

		autositbot_co:Resume()
		targetbot_co:Resume()
		tetherbot_co:Resume()
		ecstate_co:Resume()

		Config:Reload(10000)

		mq.delay(10)
	end
end


--
-- Execution
--

main()
