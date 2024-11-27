local mq = require('mq')


function ManagedCoroutine(factory, name)
	local self = {}
	self.__type__ = 'ManagedCoroutine'

	name = name or 'Unnamed'
	local m_co = coroutine.create(factory)

	self.Resume = function()
		if coroutine.status(m_co) == 'dead' then
			m_co = coroutine.create(factory)
		end
		local status, res = coroutine.resume(m_co)
		if not status then
			print(name .. ': ' .. res)
			m_co = coroutine.create(factory)
			status, res = coroutine.resume(m_co)
			if not status then
				print('L2: ' .. tostring(res))
				m_co = coroutine.create(factory)
			end
		end
	end

	return self
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
