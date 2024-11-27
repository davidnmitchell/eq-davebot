local mq = require('mq')
local mychar = require('mychar')
local co = require('co')
require('actions.s_sit')

local autositbot = {}


--
-- Globals
--

local actionqueue = {}

local State = {}
local Config = {}


--
-- Functions
--

local function log(msg)
	print('(autositbot) ' .. msg)
end

local function do_check()
	local min_mana = Config.AutoSit.MinMana()
	local min_hps = Config.AutoSit.MinHPs()
	local override_on_move = Config.AutoSit.OverrideOnMove()

	if mq.TLO.Me.Moving() and State.NoSitUntil <= mq.gettime() then
		local seconds = Config.AutoSit.OverrideSeconds()
		State.NoSitUntil = mq.gettime() + (1000 * seconds)
	end

	if mychar.ReadyToCast() and not mychar.InCombat() and (mq.TLO.Me.PctMana() < min_mana or mq.TLO.Me.PctHPs() < min_hps) and mychar.CanRest() and mychar.Standing() and (not override_on_move or State.NoSitUntil <= mq.gettime()) then
		actionqueue.AddUnique(ScpSit())
	end

	if override_on_move and mychar.Standing() and State.Sitting then
		State.Sitting = false
		if mq.TLO.Me.PctMana() < min_mana or mq.TLO.Me.PctHPs() < min_hps then
			local seconds = Config.AutoSit.OverrideSeconds()
			log('Overriding sit for ' .. seconds .. ' seconds')
			State.NoSitUntil = mq.gettime() + (1000 * seconds)
		end
	end
end


--
-- Init
--

function autositbot.Init(state, cfg, aq)
	State = state
	Config = cfg
	actionqueue = aq
end


---
--- Main Loop
---

function autositbot.Run()
	log('Up and running')
	while true do
		if State.Mode ~= 1 then
			do_check()
		end
		co.yield()
	end
end

return autositbot