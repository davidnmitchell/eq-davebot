local mq              = require('mq')
local co              = require('co')
local spells          = require('spells')
local lua             = require('lua')
local heartbeat       = require('heartbeat')
local tlo             = require('tlo')
local mychar          = require('mychar')
local drivebot        = require('drivebot')
local songbot         = require('songbot')
local targetbot       = require('targetbot')
local tetherbot       = require('tetherbot')
local teameventbot    = require('teameventbot')
local autositbot      = require('autositbot')
local gembot          = require('gembot')
local healbot         = require('healbot')
local meleebot        = require('meleebot')
local petbot          = require('petbot')
local debuffbot       = require('debuffbot')
local crowdcontrolbot = require('crowdcontrolbot')
local dotbot          = require('dotbot')
local nukebot         = require('nukebot')
local buffbot         = require('buffbot')
require('eqclass')
require('config')
require('state')


--
-- Globals
--

local MyClass = EQClass:new()
local Ini = Ini:new()
local State = BotState:new(Ini)
local Config = Config:new('davebot', State, Ini)

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

local function Shutdown()
	lua.KillScriptIfRunning('castqueue')
	Running = false
end


--
-- Main
--
-- TODO: Individual class spell lists/abilities (scan Book and write to ini?)
-- TODO: Warn when MainTank/MainAssist not set (idles most offense routines and does not say anyting about it)
-- TODO: Check for a more powerful buff before buffing (see autotoon)
-- TODO: Immunity/resist memory by mob name/type (save to ini?)
-- TODO: Summon food/drink (MQ2FeedMe?)
-- TODO: Stuns
-- TODO: AoE
-- TODO: Charms
-- TODO: Handle zoning better (see autotoon)
-- TODO: Autoload any missing plugins
-- TODO: Short lived combat buffs
-- TODO: Cure detrimental effects (target datatype)
-- TODO: Finding and pulling (see autotoon)
-- TODO: Lose aggro logic
-- TODO: Have all CC members communicate
-- TODO: /setwintitle, /foreground /setprio
-- TODO: Loot
-- TODO: Auto social build
-- TODO: Match category names across all bots
-- TODO: Items and Alt to other bots besides buffbot
-- TODO: Magician summon weapons
-- TODO: When enchanter is cycling for mez, pet isn't attacking or is attacking wrong target
-- TODO: Secondary mez takes over when primary is OOM
-- TODO: GUI? (see autotoon)

local function main()
	mq.cmd('/setwintitle ' .. mq.TLO.Me.Name())

	mq.bind(
		'/db',
		function(...)
			local args = { ... }
			if args[1] == 'shutdown' then
				Shutdown()
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

	--bc.InitServer()

	local state_co = ManagedCoroutine:new(
		function()
			State:Run()
		end
	)
	-- tlo.Init(Config)
	-- local tlo_co = ManagedCoroutine:new(
	-- 	function()
	-- 		tlo.Run()
	-- 	end
	-- )
	teameventbot.Init(State, Config)
	local teameventbot_co = ManagedCoroutine:new(
		function()
			teameventbot.Run()
		end
	)
	drivebot.Init(State, Config)
	local drivebot_co = ManagedCoroutine:new(
		function()
			drivebot.Run()
		end
	)
	autositbot.Init(State, Config)
	local autositbot_co = ManagedCoroutine:new(
		function()
			autositbot.Run()
		end
	)
	gembot.Init(State, Config)
	local gembot_co = ManagedCoroutine:new(
		function()
			gembot.Run()
		end
	)
	targetbot.Init(State, Config)
	local targetbot_co = ManagedCoroutine:new(
		function()
			targetbot.Run()
		end
	)
	healbot.Init(State, Config)
	local healbot_co = ManagedCoroutine:new(
		function()
			healbot.Run()
		end
	)
	crowdcontrolbot.Init(State, Config)
	local crowdcontrolbot_co = ManagedCoroutine:new(
		function()
			crowdcontrolbot.Run()
		end
	)
	dotbot.Init(State, Config)
	local dotbot_co = ManagedCoroutine:new(
		function()
			dotbot.Run()
		end
	)
	debuffbot.Init(State, Config)
	local debuffbot_co = ManagedCoroutine:new(
		function()
			debuffbot.Run()
		end
	)
	nukebot.Init(State, Config)
	local ddbot_co = ManagedCoroutine:new(
		function()
			nukebot.Run()
		end
	)
	buffbot.Init(State, Config)
	local buffbot_co = ManagedCoroutine:new(
		function()
			buffbot.Run()
		end
	)
	petbot.Init(State, Config)
	local petbot_co = ManagedCoroutine:new(
		function()
			petbot.Run()
		end
	)
	meleebot.Init(State, Config)
	local meleebot_co = ManagedCoroutine:new(
		function()
			meleebot.Run()
		end
	)
	tetherbot.Init(State, Config)
	local tetherbot_co = ManagedCoroutine:new(
		function()
			tetherbot.Run()
		end
	)
	if MyClass.IsBard then
		songbot.Init(State, Config)
	end
	local songbot_co = ManagedCoroutine:new(
		function()
			songbot.Run()
		end
	)
	local ecstate_co = ManagedCoroutine:new(
		function()
			while true do
				if State.IsEarlyCombatActive and not mychar.InCombat() and State.EarlyCombatActiveSince + 10000 < mq.gettime() then
					State:MarkEarlyCombatInactive()
				end
				co.yield()
			end
		end
	)
	local warnings_co = ManagedCoroutine:new(
		function()
			local last_printed_main_assist = 0
			local last_printed_main_tank = 0
			while true do
				if mq.TLO.Group() then
					if mq.TLO.Group.MainAssist() == nil and last_printed_main_assist + 60000 < mq.gettime() then
						print('No MainAssist set in group')
						last_printed_main_assist = mq.gettime()
					end
					if mq.TLO.Group.MainTank() == nil and last_printed_main_tank + 60000 < mq.gettime() then
						print('No MainTank set in group')
						last_printed_main_tank = mq.gettime()
					end
				end
				co.yield()
			end
		end
	)
	local spellwrite_co = ManagedCoroutine:new(
		function()
			local last_spell_count = 0
			while true do
				local spell_count = spells.KnownSpellCount()
				if spell_count > last_spell_count then
					last_spell_count = spell_count
					spells.DumpSpellBook(Ini, 'Spells')
				end
			end
		end
	)

	print('DaveBot running')
	while Running == true do
		mq.doevents()

		if MyClass.HasSpells or MyClass.IsBard then
			gembot_co:Resume()
			spellwrite_co:Resume()
		end

		if MyClass.HasSpells then
			CheckBot('castqueue')
		end

		if Config:Heal():Enabled() then healbot_co:Resume() end
		if Config:CrowdControl():Enabled() then crowdcontrolbot_co:Resume() end
		if Config:Debuff():Enabled() then debuffbot_co:Resume() end
		if Config:Dot():Enabled() then dotbot_co:Resume() end
		if Config:Dd():Enabled() then ddbot_co:Resume() end
		if Config:Melee():Enabled() then meleebot_co:Resume() end

		if Config:Buff():Enabled() then buffbot_co:Resume() end
		if Config:Pet():AutoCast() or Config:Pet():AutoAttack() then petbot_co:Resume() end
		if Config:AutoSit():Enabled() then autositbot_co:Resume() end

		if MyClass.IsBard and Config:Twist():Enabled() then songbot_co:Resume() end

		state_co:Resume()
		-- tlo_co:Resume()
		teameventbot_co:Resume()
		targetbot_co:Resume()
		tetherbot_co:Resume()
		drivebot_co:Resume()
		ecstate_co:Resume()
		warnings_co:Resume()

		Config:Reload(10000)

		-- if mq.TLO.Me.Zoning() then Shutdown() end

		mq.delay(10)
	end
end


--
-- Execution
--

main()
