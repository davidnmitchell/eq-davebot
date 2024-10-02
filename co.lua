local mq = require('mq')


ManagedCoroutine = {}
ManagedCoroutine.__index = ManagedCoroutine

function ManagedCoroutine:new(factory)
	local obj = {}
	setmetatable(obj, ManagedCoroutine)

	obj._factory = factory
	obj._co = coroutine.create(
		function()
		end
	)
	coroutine.resume(obj._co)

	return obj
end

function ManagedCoroutine:Resume()
	if coroutine.status(self._co) == 'dead' then
		self._co = coroutine.create(self._factory)
	end
	local status, res = coroutine.resume(self._co)
	if not status then
		print(res)
		self._co = coroutine.create(self._factory)
	end
end


local co = {}

function co.yield(...)
	if coroutine.isyieldable() then
		coroutine.yield(...)
	end
end

function co.delay(ms, end_early_predicate)
	end_early_predicate = end_early_predicate or function() return false end
	local timeout = mq.gettime() + ms
	while true do
		co.yield()
		if mq.gettime() >= timeout then return false end
		if end_early_predicate() then return true end
	end
end

function co.noop()
	return coroutine.create(
		function()
			while true do
				co.yield()
			end
		end
	)
end

return co
