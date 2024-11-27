local mq              = require('mq')
local co              = require('co')
local spells          = require('spells')
local lua             = require('lua')
local mychar          = require('mychar')
local actionqueue     = require('actionqueue')
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
local common          = require('common')


--
-- Globals
--

local MyClass = EQClass:new()
local Ini = Ini:new()
local State = BotState(Ini)
local Config = Config(State, Ini)

local Running = true
-- local LastHeardFrom = {}


--
-- Functions
--

-- local function CheckBot(name)
-- 	local timeout = 15000
-- 	if name == 'buffbot' then timeout = 20000 end
-- 	if heartbeat.CheckProcess(name, LastHeardFrom[name], timeout) then
-- 		LastHeardFrom[name] = mq.gettime()
-- 	end
-- end

local function Shutdown()
	lua.KillScriptIfRunning('castqueue')
	Running = false
end


--
-- Main
--
-- TODO: All bots handle someone's pet as tank
-- TODO: Queueing sit with priority 99 spam
-- TODO: Flags in configs for someone's pet as tank
-- TODO: Healbot with multiple tiers for HOT
-- TODO: /drive cast to handle items and aa
-- TODO: Only run /afollow with tetherbot when driver nav is active
-- -- TODO: Healbot can cause char to bounce between targets due to lag from queueing if we have Xamox switch targets in a fight
-- TODO: Auto social build
-- TODO: Handle death situations: rez, stop healing, untether, kick + healer merc + reinvite
-- -- TODO: Feature: SpellBar under a Flag has some sort of first OPEN option
-- -- TODO: Abort queued buff spells in combat
-- TODO: Bard pulls
-- -- TODO: Meleebot disables/re-enables tether
-- TODO: Short lived combat buffs
-- TODO: Automatically generated or standardized type based spell keys so /drive grp heal can use
-- TODO: Individual class spell lists/abilities (scan Book and write to ini?)
-- -- TODO: Move /dbcq under /drive
-- -- TODO: Mode 1 doesn't turn off crowdcontrolbot
-- -- TODO: /drive grp shm heal maintank
-- TODO: Bard sometimes doesn't retwist song of travel after zoning
-- TODO: Items and Alt to other bots besides buffbot
-- -- TODO: Feature: configs with key Pcts needs a way to overlay with different flags
-- -- TODO: Feature: buffs need a way to additively overlay with different flags
-- TODO: Feature: automatic pet summon items for mag
-- TODO: Check for a more powerful buff before buffing (see autotoon)
-- TODO: Immunity/resist memory by mob name/type (save to ini?)
-- -- TODO: Summon food/drink (MQ2FeedMe?)
-- TODO: Stuns
-- TODO: AoE
-- TODO: Charms
-- TODO: Handle zoning better (see autotoon)
-- TODO: Autoload any missing plugins
-- TODO: Cure detrimental effects (target datatype)
-- TODO: Finding and pulling (see autotoon)
-- TODO: Lose aggro logic
-- TODO: Have all CC members communicate
-- TODO: CCbot needs a way to ignore an add
-- TODO: Secondary mez takes over when primary is OOM
-- -- TODO: /setwintitle, /foreground /setprio
-- TODO: Loot
-- TODO: Match category key-names across all bots
-- -- TODO: Magician summon weapons
-- TODO: GUI? (see autotoon)
-- TODO: Meleebot needs to be able to switch to secondary targets if necessary
-- TODO: Meleebot needs to be able to engage an add when tank is away on a pull
-- TODO: Timmaayy is casting clarity on Pystoffe

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
	-- mq.bind(
	-- 	'/dbhb',
	-- 	function(...)
	-- 		local args = { ... }
	-- 		LastHeardFrom[args[1]] = mq.gettime()
	-- 	end
	-- )

	--bc.InitServer()

	local state_co = ManagedCoroutine(
		function()
			State.Run()
		end,
		"state_co"
	)
	actionqueue.Init(State, Config)
	local actionqueue_co = ManagedCoroutine(
		function()
			actionqueue.Run()
		end,
		"actionqueue_co"
	)
	-- tlo.Init(Config)
	-- local tlo_co = ManagedCoroutine(
	-- 	function()
	-- 		tlo.Run()
	-- 	end
	-- )
	teameventbot.Init(State, Config)
	local teameventbot_co = ManagedCoroutine(
		function()
			teameventbot.Run()
		end,
		"teameventbot_co"
	)
	drivebot.Init(State, Config, actionqueue)
	local drivebot_co = ManagedCoroutine(
		function()
			drivebot.Run()
		end,
		"drivebot_co"
	)
	autositbot.Init(State, Config, actionqueue)
	local autositbot_co = ManagedCoroutine(
		function()
			autositbot.Run()
		end,
		"autositbot_co"
	)
	gembot.Init(State, Config, actionqueue)
	local gembot_co = ManagedCoroutine(
		function()
			gembot.Run()
		end,
		"gembot_co"
	)
	targetbot.Init(State, Config, actionqueue)
	local targetbot_co = ManagedCoroutine(
		function()
			targetbot.Run()
		end,
		"targetbot_co"
	)
	healbot.Init(State, Config, actionqueue)
	local healbot_co = ManagedCoroutine(
		function()
			healbot.Run()
		end,
		"healbot_co"
	)
	crowdcontrolbot.Init(State, Config, actionqueue)
	local crowdcontrolbot_co = ManagedCoroutine(
		function()
			crowdcontrolbot.Run()
		end,
		"crowdcontrolbot_co"
	)
	dotbot.Init(State, Config, actionqueue)
	local dotbot_co = ManagedCoroutine(
		function()
			dotbot.Run()
		end,
		"dotbot_co"
	)
	debuffbot.Init(State, Config, actionqueue)
	local debuffbot_co = ManagedCoroutine(
		function()
			debuffbot.Run()
		end,
		"debuffbot_co"
	)
	nukebot.Init(State, Config, actionqueue)
	local ddbot_co = ManagedCoroutine(
		function()
			nukebot.Run()
		end,
		"ddbot_co"
	)
	buffbot.Init(State, Config, actionqueue)
	local buffbot_co = ManagedCoroutine(
		function()
			buffbot.Run()
		end,
		"buffbot_co"
	)
	petbot.Init(State, Config, actionqueue)
	local petbot_co = ManagedCoroutine(
		function()
			petbot.Run()
		end,
		"petbot_co"
	)
	meleebot.Init(State, Config, actionqueue)
	local meleebot_co = ManagedCoroutine(
		function()
			meleebot.Run()
		end,
		"meleebot_co"
	)
	tetherbot.Init(State, Config, actionqueue)
	local tetherbot_co = ManagedCoroutine(
		function()
			tetherbot.Run()
		end,
		"tetherbot_co"
	)
	if MyClass.IsBard then
		songbot.Init(State, Config, actionqueue)
	end
	local songbot_co = ManagedCoroutine(
		function()
			songbot.Run()
		end,
		"songbot_co"
	)
	local ecstate_co = ManagedCoroutine(
		function()
			while true do
				if State.IsEarlyCombatActive and not mychar.InCombat() and State.EarlyCombatActiveSince + 10000 < mq.gettime() then
					State.MarkEarlyCombatInactive()
				end
				co.yield()
			end
		end,
		"ecstate_co"
	)
	local warnings_co = ManagedCoroutine(
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
		end,
		"warnings_co"
	)
	local spellwrite_co = ManagedCoroutine(
		function()
			local last_spell_count = 0
			while true do
				if not mychar.InCombat() then
					local spell_book = spells.KnownSpells()
					if #spell_book > last_spell_count then
						last_spell_count = #spell_book
						spells.DumpSpellBook(Ini, 'Spells', spell_book)
					end
				end
				co.delay(1000)
			end
		end,
		"spellwrite_co"
	)
	local aawrite_co = ManagedCoroutine(
		function()
			local last_aa_count = 0
			while true do
				if not mychar.InCombat() then
					local aas = {}
					for i=1, 9999 do
						local rank = mq.TLO.AltAbility(i).Rank()
						if rank ~= nil and rank > 0 then
							local reuse_time = mq.TLO.AltAbility(i).ReuseTime()
							if reuse_time ~= nil and reuse_time > 0 then
								table.insert(aas, i)
							end
						end
						if i % 25 == 0 then
							co.yield()
						end
					end

					if #aas > last_aa_count then
						last_aa_count = #aas
						spells.DumpAAs(Ini, 'Spells', aas)
					end
				end
				co.delay(1000)
			end
		end,
		"aawrite_co"
	)
	local invwrite_co = ManagedCoroutine(
		function()
			local last_item_count = 0
			while true do
				if not mychar.InCombat() then
					local items = {}
					for i=0, 34 do
						local item = mq.TLO.Me.Inventory(i)()
						if item ~= nil then
							local effect = mq.TLO.Me.Inventory(i).EffectType()
							if effect == 'Click Inventory' or effect == 'Click Worn' then
								local spell = mq.TLO.Me.Inventory(i).Spell()
								if spell ~= nil then
									table.insert(items, { name=item, spell=spell })
								end
							end

							local slots = mq.TLO.Me.Inventory(i).Container()
							if slots ~= nil and slots > 0 then
								for j=1, slots do
									local iitem = mq.TLO.Me.Inventory(i).Item(j)()
									if iitem ~= nil then
										local ieffect = mq.TLO.Me.Inventory(i).Item(j).EffectType()
										if ieffect == 'Click Inventory' or ieffect == 'Click Worn' then
											local ispell = mq.TLO.Me.Inventory(i).Item(j).Spell()
											if ispell ~= nil then
												table.insert(items, { name=iitem, spell=ispell })
											end
										end
									end
								end
							end
						end
						if i % 25 == 0 then
							co.yield()
						end
					end

					if #items > last_item_count then
						last_item_count = #items
						spells.DumpItems(Ini, 'Spells', items)
					end
				end
				co.delay(1000)
			end
		end,
		"aawrite_co"
	)

	print('DaveBot running')
	while Running == true do
		mq.doevents()

		actionqueue_co.Resume()

		if not mq.TLO.Me.Dead() and not mq.TLO.Me.Zoning() then
			aawrite_co.Resume()
			invwrite_co.Resume()
			if MyClass.HasSpells or MyClass.IsBard then
				gembot_co.Resume()
				spellwrite_co.Resume()
			end

			if Config.Heal.Enabled() then healbot_co.Resume() end
			if Config.CrowdControl.Enabled() then crowdcontrolbot_co.Resume() end
			if Config.Debuff.Enabled() then debuffbot_co.Resume() end
			if Config.Dot.Enabled() then dotbot_co.Resume() end
			if Config.Dd.Enabled() then ddbot_co.Resume() end
			if Config.Melee.Enabled() then meleebot_co.Resume() end

			if Config.Buff.Enabled() or Config.CombatBuff.Enabled() then buffbot_co.Resume() end
			if Config.Pet.AutoCast() or Config.Pet.AutoAttack() then petbot_co.Resume() end
			if Config.AutoSit.Enabled() then autositbot_co.Resume() end

			if MyClass.IsBard and Config.Twist.Enabled() then songbot_co.Resume() end
		else
			State.TetherClear()
		end

		state_co.Resume()
		-- tlo_co.Resume()
		teameventbot_co.Resume()
		targetbot_co.Resume()
		tetherbot_co.Resume()
		drivebot_co.Resume()
		ecstate_co.Resume()
		warnings_co.Resume()

		Config.Reload(10000)

		mq.delay(10)
	end
end


--
-- Execution
--

main()
