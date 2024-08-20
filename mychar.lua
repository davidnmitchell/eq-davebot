local mq = require('mq')


local mychar = {}

function mychar.ReadyToCast()
	return not mq.TLO.Me.Moving() and mq.TLO.Cast.Status() == 'I'
end

function mychar.Casting()
	local status = mq.TLO.Cast.Status()
	return status ~= 'C'
end

function mychar.InCombat()
	return mq.TLO.Me.XTarget() > 0
	-- for i=1,mq.TLO.DanNet.PeerCount() do
		-- local peer = mq.TLO.DanNet.Peers(i)()
		-- local combat = common.query(peer, 'Me.Combat')
		-- if combat then
			-- return true
		-- end
	-- end
	-- return false
end

function mychar.CanRest()
	return mq.TLO.Me.CombatState() == 'ACTIVE'
end

function mychar.Standing()
	return mq.TLO.Me.State() == 'STAND'
end

return mychar