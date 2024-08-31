local mq = require('mq')

local group = {}

local last_checked = 0
function group.MainAssistCheck(timeout)
	if not mq.TLO.Group.MainAssist() then
		if last_checked + timeout < mq.gettime() then
			last_checked = mq.gettime()
			return true
		end
	end
end

return group