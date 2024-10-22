local mq = require('mq')
local co = require('co')
local str= require('str')
local common = require('common')


local function log(msg)
	print('(state) ' .. msg)
end


BotState = {}
BotState.__index = BotState

function BotState:new(ini)
	local obj = {}
	setmetatable(obj, self)

	obj._ini = ini

	obj.Mode = 1
	obj.Flags = {}
	obj.IsCrowdControlActive = false
	obj.IsBardCastActive = false
	obj.IsEarlyCombatActive = false
	obj.EarlyCombatActiveSince = 0

	obj.MyCharStillSince = 0
	obj.MyCharLastLoc = ''

	obj.TetherStatus = 'N'
	obj.TetherDetail = 'NONE'

	obj.Locks = {}
	obj.LockTimeouts = {}

	obj.Immunes = {}
	obj.Sitting = false
	obj.NoSitUntil = 0
	obj.InCombat = false
	obj.LastTwistAt = 0
	obj.TargetHistory = {}

	obj:Read()
	return obj
end

function BotState:_moving()
	local loc = mq.TLO.Me.MQLoc()
	local m = loc ~= self.MyCharLastLoc
	self.MyCharLastLoc = loc
	return m
end

function BotState:Run()
	log('Up and running')
	while true do
		if self:_moving() then
			self.MyCharStillSince = mq.gettime()
		end

		co.yield()
	end
end

function BotState:Read()
	self.Mode = self._ini:Number('State', 'Mode', 1)
	self.Flags = str.Split(self._ini:String('State', 'Flags', ''), ',')

	self.TetherDetail = tostring(self._ini:String('State', 'Tether', 'NONE'))
	if self.TetherDetail == 'NONE' then
		self.TetherStatus = 'N'
	elseif tonumber(self.TetherDetail) ~= nil then
		self.TetherStatus = 'F'
	else
		self.TetherStatus = 'C'
	end
end

function BotState:ChangeMode(mode)
	local new_mode = tonumber(mode)
	if new_mode ~= nil then
		self.Mode = new_mode
		self._ini:WriteNumber('State', 'Mode', self.Mode)
		log('Mode is now ' .. self.Mode)
	else
		log('Tried to set Mode to nil')
	end
end

function BotState:SetFlag(flag)
	if flag ~= nil then
		if not common.ArrayHasValue(self.Flags, flag) then
			table.insert(self.Flags, flag)
			local csv = common.TableAsCsv(self.Flags)
			self._ini:WriteString('State', 'Flags', csv)
			log('Set Flag ' .. flag)
		end
	else
		log('Tried to set nil Flag')
	end
end

function BotState:UnsetFlag(flag)
	if flag ~= nil then
		local idx = common.TableIndexOf(self.Flags, flag)
		if idx > 0 then
			table.remove(self.Flags, idx)
			local csv = common.TableAsCsv(self.Flags)
			self._ini:WriteString('State', 'Flags', csv)
			log('Unset Flag ' .. flag)
		end
	else
		log('Tried to unset nil Flag')
	end
end

function BotState:MarkCrowdControlActive()
	self.IsCrowdControlActive = true
end
function BotState:MarkCrowdControlInactive()
	self.IsCrowdControlActive = false
end
function BotState:MarkBardCastActive()
	self.IsBardCastActive = true
end
function BotState:MarkBardCastInactive()
	self.IsBardCastActive = false
end
function BotState:MarkEarlyCombatActive()
	self.IsEarlyCombatActive = true
	self.EarlyCombatActiveSince = mq.gettime()
end
function BotState:MarkEarlyCombatInactive()
	self.IsEarlyCombatActive = false
end

function BotState:MyCharHasNotMovedFor()
	return (mq.gettime() - self.MyCharStillSince) / 1000
end

function BotState:TetherClear()
	self.TetherStatus = 'N'
	self.TetherDetail = 'NONE'
	self._ini:WriteString('State', 'Tether', self.TetherDetail)
end
function BotState:TetherFollow(id)
	self.TetherStatus = 'F'
	self.TetherDetail = tostring(id)
	self._ini:WriteString('State', 'Tether', self.TetherDetail)
end
function BotState:TetherFlee(id)
	self:TetherFollow(id)
	self.TetherStatus = 'R'
end
function BotState:TetherPause()
	self.TetherStatus = 'P'
end
function BotState:TetherResume()
	self.TetherStatus = 'F'
end
function BotState:TetherCamp()
	self.TetherStatus = 'C'
	self.TetherDetail = mq.TLO.Me.MQLoc()
	self._ini:WriteString('State', 'Tether', self.TetherDetail)
end

function BotState:LastTargetOf(func)
	for i, h_id in ipairs(self.TargetHistory) do
		if func(h_id) then
			return h_id
		end
	end
	return 0
end

function BotState:_AcquireLock(lock_name, process_name, release_timeout)
	assert(lock_name)
	assert(process_name)
	-- print(lock_name)
	-- print(self.Locks[lock_name]) -- or self.Locks[lock_name]:len() == 0 or self.Locks[lock_name] == process_name or not self.LockTimeouts[lock_name] or self.LockTimeouts[lock_name] <= mq.gettime()
	if self.Locks[lock_name] == nil or self.Locks[lock_name]:len() == 0 or self.Locks[lock_name] == process_name or not self.LockTimeouts[lock_name] or self.LockTimeouts[lock_name] <= mq.gettime() then
		self.Locks[lock_name] = process_name
		self.LockTimeouts[lock_name] = mq.gettime() + (release_timeout or 2000)
		return true
	else
		return false
	end
end

function BotState:AcquireLock(lock_name, process_name, release_timeout)
	local locked = self:_AcquireLock(lock_name, process_name, release_timeout)
	if locked then
		return true, Lock:new(process_name, self.LockTimeouts[lock_name])
	else
		return false, {}
	end
end

function BotState:WaitOnAndAcquireLock(lock_name, process_name, release_timeout, acquire_timeout)
	co.delay(
		acquire_timeout or 2000,
		function()
			return self:_AcquireLock(lock_name, process_name, release_timeout)
		end
	)
	local locked = self.Locks[lock_name] == process_name
	if locked then
		return true, Lock:new(process_name, self.LockTimeouts[lock_name])
	else
		return false, {}
	end
end

function BotState:ReleaseLock(lock_name, process_name)
	assert(lock_name)
	assert(process_name)
	if self.Locks[lock_name] == nil or self.Locks[lock_name]:len() == 0 or self.Locks[lock_name] == process_name then
		self.Locks[lock_name] = ''
		self.LockTimeouts[lock_name] = 0
		return true
	else
		return false
	end
end

Lock = {}
Lock.__index = Lock

function Lock:new(process_name, release_at)
	local obj = {}
	setmetatable(obj, self)

	obj.ProcessName = process_name
	obj.ReleaseAt = release_at

	return obj
end
