local mq = require('mq')
require('ini')
local mychar = require('mychar')


Autosit = {}
Autosit.__index = Autosit

--
-- Private methods
--

local function _build_ini(self, ini)
	print('Building autosit config')
	local auto_sit = ini:Section('AutoSit')

	auto_sit:WriteBoolean('Enabled', true)
	auto_sit:WriteNumber('MinHPs', 95)
	auto_sit:WriteNumber('MinMana', 95)
	auto_sit:WriteBoolean('OverrideOnMove', true)
	auto_sit:WriteNumber('OverrideSeconds', 10)
end

local function _load(self)
	local ini = Ini:new()

	if ini:IsMissing('AutoSit', 'Enabled') then _build_ini(self, ini) end

	local auto_sit = ini:Section('AutoSit')
	self._enabled = auto_sit:Boolean('Enabled', true)
	self._min_hps = auto_sit:Number('MinHPs', 95)
	self._min_mana = auto_sit:Number('MinMana', 95)
	self._override_on_move = auto_sit:Boolean('OverrideOnMove', true)
	self._override_seconds = auto_sit:Number('OverrideSeconds', 10)

	print('Autosit config loaded')
end

--
-- Public methods
--

function Autosit:new()
	local obj = {}
	setmetatable(obj, Autosit)
	_load(obj)

	obj._sitting = false
	obj._override = 0

	return obj
end

function Autosit:Check()
	if self._enabled then
		if self._override > 0 then
			self._override = self._override - 1
		end

		if mychar.ReadyToCast() and not mychar.InCombat() and (mq.TLO.Me.PctMana() < self._min_mana or mq.TLO.Me.PctHPs() < self._min_hps) and mychar.CanRest() and mychar.Standing() and (not self._override_on_move or self._override == 0) then
			mq.cmd('/sit')
			self._sitting = true
			print(mq.TLO.Me.PctHPs() .. ':' .. mq.TLO.Me.PctMana() .. ' ' .. mq.TLO.Me.CombatState())
		end

		if self._override_on_move and mychar.Standing() and self._sitting then
			self._sitting = false
			if mq.TLO.Me.PctMana() < self._min_mana or mq.TLO.Me.PctHPs() < self._min_hps then
				print('Overriding sit')
				self._override = 100 * self._override_seconds
			end
		end
	end
end
