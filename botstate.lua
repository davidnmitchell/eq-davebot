local mq = require('mq')
local common = require('common')

BotState = {}
BotState.__index = BotState

--
-- Private methods
--

local function _build_ini(self)
	print('Building state')
	local state = self._ini:Section('State')

	state:WriteNumber('Mode', 1)
	state:WriteNumber('AutoCombatMode', 5)
end

local function _load(self)
	if self._ini:IsMissing('State', 'Mode') then _build_ini(self) end

	local state = self._ini:Section('State')

	self.Mode = state:Number('Mode', 1)
	self.AutoCombatMode = state:Number('AutoCombatMode', 5)

	print('State loaded')
end

local function _bot_mode_callback(self)
	return function(line, mode)
		self.Mode = tonumber(mode)
		self._ini:WriteNumber('State', 'Mode', self.Mode)
		print(self.ProcessName .. ': mode set to ' .. self.Mode)
	end
end

local function _auto_combat_mode_callback(self)
	return function (line, mode)
		self.AutoCombatMode = tonumber(mode)
		self._ini:WriteNumber('State', 'AutoCombatMode', self.AutoCombatMode)
		print(self.ProcessName .. ': auto combat mode set to ' .. self.AutoCombatMode)
	end
end

local function _crowd_control_active_callback(self)
	return function (line)
		self.CrowdControlActive = true
		print(self.ProcessName .. ': crowd control active')
	end
end

local function _crowd_control_inactive_callback(self)
	return function (line)
		self.CrowdControlActive = false
		print(self.ProcessName .. ': crowd control inactive')
	end
end

local function _bard_cast_active_callback(self)
	return function (line)
		self.BardCastActive = true
		print(self.ProcessName .. ': bard cast active')
	end
end

local function _bard_cast_inactive_callback(self)
	return function (line)
		self.BardCastActive = false
		print(self.ProcessName .. ': bard cast inactive')
	end
end


local function _Listen(self)
	mq.event('mode_set', '#*#NOTIFY BOTMODE #1#', _bot_mode_callback(self))
	mq.event('autocombat_mode_set', '#*#NOTIFY BOTAUTOCOMBATMODEIS #1#', _auto_combat_mode_callback(self))

	if self.watch_cc then
		mq.event('ccactive', 'NOTIFY CCACTIVE', _crowd_control_active_callback(self))
		mq.event('ccinactive', '#*#NOTIFY CCINACTIVE', _crowd_control_inactive_callback(self))
	end
	if self.watch_bc then
		mq.event('bcactive', '#*#NOTIFY BCACTIVE', _bard_cast_active_callback(self))
		mq.event('bcinactive', '#*#NOTIFY BCINACTIVE', _bard_cast_inactive_callback(self))
	end
end

--
-- Public methods
--

function BotState:new(process_name, watch_cc, watch_bc)
	local mt = {}
	setmetatable(mt, self)
	self.ProcessName = process_name or 'bot'
	self._ini = Ini:new()
	_load(self)

	self.NormalMode = 1
	self.ShortTravelMode = 2
	self.LongTravelMode = 3
	self.CampMode = 4
	self.NormalCombatMode = 5

	self.CrowdControlActive = false
	self.watch_cc = true
	if watch_cc ~= nil then self.watch_cc = watch_cc end
	self.BardCastActive = false
	self.watch_bc = false
	if watch_bc ~= nil then self.watch_bc = watch_bc end

	_Listen(self)
	print('Current mode: ' .. self.Mode)
	return mt
end

