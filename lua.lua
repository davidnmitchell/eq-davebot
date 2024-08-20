local mq = require('mq')

local lua = {}


function lua.IsScriptRunning(name)
	local status = mq.TLO.Lua.Script(name).Status()
	return status ~= nil and status == 'RUNNING'
end

function lua.RunScriptIfNotRunning(name)
	if not lua.IsScriptRunning(name) then
		mq.cmd('/lua run ' .. name)
	end
end

function lua.RunScriptAndBlock(name)
	mq.cmd('/lua run ' .. name)
	mq.delay(50)
	while mq.TLO.Lua.Script(name).Status() == 'RUNNING' do
		mq.delay(50)
	end
end

return lua