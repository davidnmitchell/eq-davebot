local mq = require('mq')

function Action(name, blocking, ready_timeout, finish_timeout)
	local self = {}
	self.__type__ = 'Action'

	self.Name = name or ''
	self.Blocking = blocking
	if self.Blocking == nil then
		self.Blocking = true
	end
	self.ReadyTimeout = ready_timeout or 10000
	self.FinishTimeout = ready_timeout or 10000

	self.log = function(msg)
		---@diagnostic disable-next-line: undefined-field
		mq.cmd.echo(string.format('\ao(action) \a-w%s', msg))
	end

	self.announce = function(msg)
		mq.cmd('/g ' .. msg)
	end

	self.ShouldSkip = function(state, cfg, ctx)
		return false, ''
	end

	self.IsReady = function(state, cfg, ctx)
		return true
	end

	self.Run = function(state, cfg, ctx) end

	self.IsFinished = function(state, cfg, ctx)
		return true
	end

	self.PostAction = function(state, cfg, ctx) end

	self.OnInterrupt = function(state, cfg, ctx) end

	return self
end
