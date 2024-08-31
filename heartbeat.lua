local mq = require('mq')
local lua = require('lua')

local heartbeat = {}

local last_sent_time = 0
function heartbeat.SendHeartBeat(process_name)
	if last_sent_time + 5000 < mq.gettime() then
		mq.cmd('/dbhb ' .. process_name)
		last_sent_time = mq.gettime()
	end
end

function heartbeat.CheckProcess(process_name, last_heard_from, timeout)
	if lua.IsScriptRunning(process_name) then
		if (last_heard_from or 0) + (timeout or 15000) < mq.gettime() then
			lua.KillScript(process_name)
			mq.delay(100)
			lua.RunScript(process_name)
			return true
		else
			return false
		end
	else
		lua.RunScript(process_name)
		return true
	end
end

return heartbeat