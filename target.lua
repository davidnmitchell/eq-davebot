local mq = require('mq')

local target = {}


function target.IsAlive(spawn_id)
	local state = mq.TLO.Spawn(spawn_id).State()
	local pct_hps = mq.TLO.Spawn(spawn_id).PctHPs()

	return state and state ~= 'DEAD' and pct_hps and pct_hps > 0
end

function target.IsInGroup(id)
	if mq.TLO.Me.ID() == id then
		return true
	end
	for i=1,mq.TLO.Group.Members() do
		if mq.TLO.Group.Member(i).ID() == id then
			return true
		end
	end
	return false
end

return target
