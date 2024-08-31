local mq = require('mq')
require('config')


BotState = {}
BotState.__index = BotState

--
-- Private methods
--
local function log(self, msg)
	print('(' .. self.ProcessName .. ') ' .. msg)
end

local function _bot_mode_callback(self)
	return function(line, mode)
		self._config:UpdateMode(tonumber(mode))
		log(self, 'Mode set to ' .. self._config:Mode())
	end
end

local function _bot_flag_set_callback(self)
	return function(line, flag)
		self._config:SetFlag(flag)
		log(self, 'Flag set ' .. flag)
	end
end

local function _bot_flag_unset_callback(self)
	return function(line, flag)
		self._config:UnsetFlag(flag)
		log(self, 'Flag unset ' .. flag)
	end
end

local function _crowd_control_active_callback(self)
	return function (line)
		self._crowd_control_active = true
		log(self, 'Crowd control active')
	end
end

local function _crowd_control_inactive_callback(self)
	return function (line)
		self._crowd_control_active = false
		log(self, 'Crowd control inactive')
	end
end

local function _bard_cast_active_callback(self)
	return function (line)
		self._bard_cast_active = true
		log(self, 'Bard cast active')
	end
end

local function _bard_cast_inactive_callback(self)
	return function (line)
		self._bard_cast_active = false
		log(self, 'Bard cast inactive')
	end
end


local function _listen(self)
	mq.event('mode_set', '#*#NOTIFY BOTMODE #1#', _bot_mode_callback(self))
	mq.event('flag_set', '#*#NOTIFY FLAGSET #1#', _bot_flag_set_callback(self))
	mq.event('flag_unset', '#*#NOTIFY FLAGUNSET #1#', _bot_flag_unset_callback(self))
	--mq.event('autocombat_mode_set', '#*#NOTIFY BOTAUTOCOMBATMODEIS #1#', _auto_combat_mode_callback(self))

	if self.watch_cc then
		mq.event('ccactive', 'NOTIFY CCACTIVE', _crowd_control_active_callback(self))
		mq.event('ccinactive', 'NOTIFY CCINACTIVE', _crowd_control_inactive_callback(self))
	end
	if self.watch_bc then
		mq.event('bcactive', 'NOTIFY BCACTIVE', _bard_cast_active_callback(self))
		mq.event('bcinactive', 'NOTIFY BCINACTIVE', _bard_cast_inactive_callback(self))
	end
end

--
-- Public methods
--

function BotState:new(persist, process_name, watch_cc, watch_bc)
	local mt = {}
	setmetatable(mt, self)

	mt.ProcessName = process_name or 'bot'

	mt._config = StateConfig:new(persist)
	mt._crowd_control_active = false
	mt._bard_cast_active = false

	-- self.ManualMode = 1
	-- self.ManagedMode = 2
	-- self.TravelMode = 3
	-- self.CampMode = 4

	mt.watch_cc = true
	if watch_cc ~= nil then mt.watch_cc = watch_cc end
	mt.watch_bc = false
	if watch_bc ~= nil then mt.watch_bc = watch_bc end

	_listen(mt)
	log(mt, 'Current mode: ' .. mt._config:Mode())
	return mt
end

function BotState:Mode()
	return self._config:Mode()
end

function BotState:Flags()
	return self._config:Flags()
end

function BotState:CrowdControlActive()
	if not self.watch_cc then log(self, 'Crowd control not watched') end
	return self._crowd_control_active
end

function BotState:UpdateCrowdControlActive()
	mq.cmd('/echo NOTIFY CCACTIVE')
end

function BotState:UpdateCrowdControlInactive()
	mq.cmd('/echo NOTIFY CCINACTIVE')
end

function BotState:BardCastActive()
	if not self.watch_bc then log(self, 'Bard cast not watched') end
	return self._bard_cast_active
end
