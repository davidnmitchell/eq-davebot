local mq = require('mq')


ManagedCoroutine = {}
ManagedCoroutine.__index = ManagedCoroutine

function ManagedCoroutine:new(factory, name)
	local obj = {}
	setmetatable(obj, ManagedCoroutine)

	obj._factory = factory
	obj._name = name or 'Unnamed'
	obj._co = coroutine.create(factory)
	-- 	function()
	-- 	end
	-- )
	-- coroutine.resume(obj._co)

	return obj
end

function ManagedCoroutine:Resume()
	if coroutine.status(self._co) == 'dead' then
		self._co = coroutine.create(self._factory)
	end
	local status, res = coroutine.resume(self._co)
	if not status then
		print(self._name .. ': ' .. res)
		self._co = coroutine.create(self._factory)
		status, res = coroutine.resume(self._co)
		if not status then
			print('L2: ' .. tostring(res))
			self._co = coroutine.create(self._factory)
		end
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
	while not end_early_predicate() do
		co.yield()
		if mq.gettime() >= timeout then return false end
	end
	return true
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
