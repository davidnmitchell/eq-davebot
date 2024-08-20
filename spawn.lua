local mq = require('mq')

local spawn = {}


function spawn.IsAlive(spawn_id)
	local state = mq.TLO.Spawn(spawn_id).State()
	local pct_hps = mq.TLO.Spawn(spawn_id).PctHPs()

	return state and state ~= 'DEAD' and pct_hps and pct_hps > 0
end

return spawn
