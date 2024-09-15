local mq = require('mq')
local mychar = require('mychar')
local co = require('co')


--
-- Globals
--

AutoSitBot = {}
AutoSitBot.__index = AutoSitBot


--
-- CTor
--

function AutoSitBot:new(config)
	local obj = {}
	setmetatable(obj, AutoSitBot)

	obj._config = config

	obj._sitting = false
	obj._override_timeout = 0

	return obj
end

--
-- Methods
--

function AutoSitBot:_log(msg)
	print('(autositbot) ' .. msg)
end

function AutoSitBot:Check()
	local min_mana = self._config:AutoSit():MinMana()
	local min_hps = self._config:AutoSit():MinHPs()
	local override_on_move = self._config:AutoSit():OverrideOnMove()

	if self._override_timeout <= mq.gettime() and mq.TLO.Me.Moving() then
		local seconds = self._config:AutoSit():OverrideSeconds()
		self._override_timeout = mq.gettime() + (1000 * seconds)
	end

	if mychar.ReadyToCast() and not mychar.InCombat() and (mq.TLO.Me.PctMana() < min_mana or mq.TLO.Me.PctHPs() < min_hps) and mychar.CanRest() and mychar.Standing() and (not override_on_move or self._override_timeout <= mq.gettime()) then
		mq.cmd('/sit')
		self._sitting = true
	end

	if override_on_move and mychar.Standing() and self._sitting then
		self._sitting = false
		if mq.TLO.Me.PctMana() < min_mana or mq.TLO.Me.PctHPs() < min_hps then
			local seconds = self._config:AutoSit():OverrideSeconds()
			self:_log('Overriding sit for ' .. seconds .. ' seconds')
			self._override_timeout = mq.gettime() + (1000 * seconds)
		end
	end
end

function AutoSitBot:Run()
	while true do
		if self._config:AutoSit():Enabled() then
			self:Check()
		end

		co.yield()
	end
end
