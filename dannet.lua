local mq = require('mq')

local dannet = {}


function dannet.PeerById(id)
	for i=1,mq.TLO.DanNet.PeerCount() do
		local peer = mq.TLO.DanNet.Peers(i)()
		local remoteid = dannet.Query(peer, 'Me.ID')
		if tonumber(id) == tonumber(remoteid) then
			return peer
		end
	end
	return nil
end

function dannet.PeerByPetId(id)
	for i=1,mq.TLO.DanNet.PeerCount() do
		local peer = mq.TLO.DanNet.Peers(i)()
		local remoteid = tonumber(dannet.Query(peer, 'Pet.ID'))
		if id == remoteid then
			return peer
		end
	end
	return nil
end


function dannet.Query(peer, query, timeout)
    mq.cmdf('/dquery %s -q "%s"', peer, query)
    mq.delay(timeout or 1000)
    return mq.TLO.DanNet(peer).Q(query)()
end

function dannet.Observe(peer, query, timeout)
    if not mq.TLO.DanNet(peer).OSet(query)() then
        mq.cmdf('/dobserve %s -q "%s"', peer, query)
    end
    mq.delay(timeout or 1000, function() return mq.TLO.DanNet(peer).O(query).Received() > 0 end)
    return mq.TLO.DanNet(peer).O(query)()
end

function dannet.Unobserve(peer, query)
    mq.cmdf('/dobserve %s -q "%s" -drop', peer, query)
end

return dannet