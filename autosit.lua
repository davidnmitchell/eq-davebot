local mq = require('mq')
local mychar = require('mychar')
require('config')


AutoSit = {}
AutoSit.__index = AutoSit


--
-- Public methods
--

function AutoSit:new(state)
	local obj = {}
	setmetatable(obj, AutoSit)

	obj._state = state
	obj._config = AutoSitConfig:new()

	obj._sitting = false
	obj._override = 0

	return obj
end

function AutoSit:Check()
	if self._config:Enabled(self._state) then
		if self._override > 0 then
			self._override = self._override - 1
		end

		local min_mana = self._config:MinMana(self._state)
		local min_hps = self._config:MinHPs(self._state)
		local override_on_move = self._config:OverrideOnMove(self._state)

		if mychar.ReadyToCast() and not mychar.InCombat() and (mq.TLO.Me.PctMana() < min_mana or mq.TLO.Me.PctHPs() < min_hps) and mychar.CanRest() and mychar.Standing() and (not override_on_move or self._override == 0) then
			mq.cmd('/sit')
			self._sitting = true
			--print(mq.TLO.Me.PctHPs() .. ':' .. mq.TLO.Me.PctMana() .. ' ' .. mq.TLO.Me.CombatState())
		end

		if override_on_move and mychar.Standing() and self._sitting then
			self._sitting = false
			if mq.TLO.Me.PctMana() < min_mana or mq.TLO.Me.PctHPs() < min_hps then
				local seconds = self._config:OverrideSeconds(self._state)
				print('Overriding sit for ' .. seconds .. ' seconds')
				self._override = 100 * seconds
			end
		end
	end

	self._config:Reload(10000)
end
