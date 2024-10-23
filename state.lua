local mq = require('mq')
local co = require('co')
local str= require('str')
local common = require('common')


local function log(msg)
	print('(state) ' .. msg)
end


function BotState(ini)
	local self = {}

	self.Mode = 1
	self.Flags = {}
	self.IsCrowdControlActive = false
	self.IsBardCastActive = false
	self.IsEarlyCombatActive = false
	self.EarlyCombatActiveSince = 0

	self.MyCharStillSince = 0
	self.MyCharLastLoc = ''

	self.TetherStatus = 'N'
	self.TetherDetail = 'NONE'

	self.Locks = {}
	self.LockTimeouts = {}

	self.Immunes = {}
	self.Sitting = false
	self.NoSitUntil = 0
	self.InCombat = false
	self.LastTwistAt = 0
	self.TargetHistory = {}

	local function moving()
		local loc = mq.TLO.Me.MQLoc()
		local m = loc ~= self.MyCharLastLoc
		self.MyCharLastLoc = loc
		return m
	end

	self.Run = function()
		log('Up and running')
		while true do
			if moving() then
				self.MyCharStillSince = mq.gettime()
			end

			co.yield()
		end
	end

	self.Read = function()
		self.Mode = ini:Number('State', 'Mode', 1)
		self.Flags = str.Split(ini:String('State', 'Flags', ''), ',')

		self.TetherDetail = tostring(ini:String('State', 'Tether', 'NONE'))
		if self.TetherDetail == 'NONE' then
			self.TetherStatus = 'N'
		elseif tonumber(self.TetherDetail) ~= nil then
			self.TetherStatus = 'F'
		else
			self.TetherStatus = 'C'
		end
	end

	self.ChangeMode = function(mode)
		local new_mode = tonumber(mode)
		if new_mode ~= nil then
			self.Mode = new_mode
			ini:WriteNumber('State', 'Mode', self.Mode)
			log('Mode is now ' .. self.Mode)
		else
			log('Tried to set Mode to nil')
		end
	end

	self.SetFlag = function(flag)
		if flag ~= nil then
			if not common.ArrayHasValue(self.Flags, flag) then
				table.insert(self.Flags, flag)
				local csv = common.TableAsCsv(self.Flags)
				ini:WriteString('State', 'Flags', csv)
				log('Set Flag ' .. flag)
			end
		else
			log('Tried to set nil Flag')
		end
	end

	self.UnsetFlag = function(flag)
		if flag ~= nil then
			local idx = common.TableIndexOf(self.Flags, flag)
			if idx > 0 then
				table.remove(self.Flags, idx)
				local csv = common.TableAsCsv(self.Flags)
				ini:WriteString('State', 'Flags', csv)
				log('Unset Flag ' .. flag)
			end
		else
			log('Tried to unset nil Flag')
		end
	end

	self.MarkCrowdControlActive = function()
		self.IsCrowdControlActive = true
	end
	self.MarkCrowdControlInactive = function()
		self.IsCrowdControlActive = false
	end
	self.MarkBardCastActive = function()
		self.IsBardCastActive = true
	end
	self.MarkBardCastInactive = function()
		self.IsBardCastActive = false
	end
	self.MarkEarlyCombatActive = function()
		self.IsEarlyCombatActive = true
		self.EarlyCombatActiveSince = mq.gettime()
	end
	self.MarkEarlyCombatInactive = function()
		self.IsEarlyCombatActive = false
	end

	self.MyCharHasNotMovedFor = function()
		return (mq.gettime() - self.MyCharStillSince) / 1000
	end

	self.TetherClear = function()
		self.TetherStatus = 'N'
		self.TetherDetail = 'NONE'
		ini:WriteString('State', 'Tether', self.TetherDetail)
	end
	self.TetherFollow = function(id)
		self.TetherStatus = 'F'
		self.TetherDetail = tostring(id)
		ini:WriteString('State', 'Tether', self.TetherDetail)
	end
	self.TetherFlee = function(id)
		self.TetherFollow(id)
		self.TetherStatus = 'R'
	end
	self.TetherPause = function()
		self.TetherStatus = 'P'
	end
	self.TetherResume = function()
		self.TetherStatus = 'F'
	end
	self.TetherCamp = function()
		self.TetherStatus = 'C'
		self.TetherDetail = mq.TLO.Me.MQLoc()
		ini:WriteString('State', 'Tether', self.TetherDetail)
	end

	self.LastTargetOf = function(func)
		for i, h_id in ipairs(self.TargetHistory) do
			if func(h_id) then
				return h_id
			end
		end
		return 0
	end

	local function acquire_lock(lock_name, process_name, release_timeout)
		assert(lock_name)
		assert(process_name)
		if self.Locks[lock_name] == nil or self.Locks[lock_name]:len() == 0 or self.Locks[lock_name] == process_name or not self.LockTimeouts[lock_name] or self.LockTimeouts[lock_name] <= mq.gettime() then
			self.Locks[lock_name] = process_name
			self.LockTimeouts[lock_name] = mq.gettime() + (release_timeout or 2000)
			return true
		else
			return false
		end
	end

	self.AcquireLock = function(lock_name, process_name, release_timeout)
		local locked = acquire_lock(lock_name, process_name, release_timeout)
		if locked then
			return true, Lock(process_name, self.LockTimeouts[lock_name])
		else
			return false, {}
		end
	end

	self.WaitOnAndAcquireLock = function(lock_name, process_name, release_timeout, acquire_timeout)
		co.delay(
			acquire_timeout or 2000,
			function()
				return acquire_lock(lock_name, process_name, release_timeout)
			end
		)
		local locked = self.Locks[lock_name] == process_name
		if locked then
			return true, Lock(process_name, self.LockTimeouts[lock_name])
		else
			return false, {}
		end
	end

	self.ReleaseLock = function(lock_name, process_name)
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

	self.Read()
	return self
end


function Lock(process_name, release_at)
	local self = {}

	self.ProcessName = process_name
	self.ReleaseAt = release_at

	return self
end