local mq = require('mq')


local teamevents = {}


function teamevents.PullStart(mob)
	mq.cmd('/g Pulling ' .. mob)
end

function teamevents.PullEnd()
	mq.cmd('/g Arrived back at camp')
end

function teamevents.PreEngage(mob)
	mq.cmd('/g Waiting to engage ' .. mob)
end

function teamevents.Engage(mob)
	mq.cmd('/g Engaging ' .. mob)
end


return teamevents