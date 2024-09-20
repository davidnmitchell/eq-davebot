local mq = require('mq')
local mychar = require('mychar')
local co = require('co')

local autositbot = {}


--
-- Globals
--

local Config = {}
local Sitting = false
local OverrideTimeout = 0


--
-- Functions
--

local function log(msg)
	print('(autositbot) ' .. msg)
end

local function do_check()
	local min_mana = Config:AutoSit():MinMana()
	local min_hps = Config:AutoSit():MinHPs()
	local override_on_move = Config:AutoSit():OverrideOnMove()

	if OverrideTimeout <= mq.gettime() and mq.TLO.Me.Moving() then
		local seconds = Config:AutoSit():OverrideSeconds()
		OverrideTimeout = mq.gettime() + (1000 * seconds)
	end

	if mychar.ReadyToCast() and not mychar.InCombat() and (mq.TLO.Me.PctMana() < min_mana or mq.TLO.Me.PctHPs() < min_hps) and mychar.CanRest() and mychar.Standing() and (not override_on_move or OverrideTimeout <= mq.gettime()) then
		mq.cmd('/sit')
		Sitting = true
	end

	if override_on_move and mychar.Standing() and Sitting then
		Sitting = false
		if mq.TLO.Me.PctMana() < min_mana or mq.TLO.Me.PctHPs() < min_hps then
			local seconds = Config:AutoSit():OverrideSeconds()
			log('Overriding sit for ' .. seconds .. ' seconds')
			OverrideTimeout = mq.gettime() + (1000 * seconds)
		end
	end
end


--
-- Init
--

function autositbot.Init(cfg)
	Config = cfg
end


---
--- Main Loop
---

function autositbot.Run()
	log('Up and running')
	while true do
		do_check()
		co.yield()
	end
end

return autositbot