local mq = require('mq')
local co = require('co')
local str = require('str')

local dannet = {}

function dannet.Peers()
	return str.Split(mq.TLO.DanNet.Peers(), '|')
end

function dannet.PeerById(id)
	for i=1,mq.TLO.DanNet.PeerCount() do
		---@diagnostic disable-next-line: redundant-parameter
		local peer = mq.TLO.DanNet.Peers(i)()
		local remoteid = dannet.Observe(peer, 'Me.ID')
		if tonumber(id) == tonumber(remoteid) then
			return peer
		end
	end
	return ''
end

function dannet.PeerByName(name)
	local server = mq.TLO.EverQuest.Server()
	for i, peer in ipairs(dannet.Peers()) do
		if peer:lower() == server:lower() .. '_' .. name:lower() then
			return peer
		end
	end
	return ''
end

function dannet.PeerByPetId(id)
	for i=1,mq.TLO.DanNet.PeerCount() do
		---@diagnostic disable-next-line: redundant-parameter
		local peer = mq.TLO.DanNet.Peers(i)()
		local remoteid = tonumber(dannet.Observe(peer, 'Pet.ID'))
		if id == remoteid then
			return peer
		end
	end
	return ''
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
	---@diagnostic disable-next-line: undefined-field
	if mq.TLO.DanNet(peer).O(query).Received() == nil then
		co.delay(
			timeout or 1000,
			function()
				---@diagnostic disable-next-line: undefined-field
				local rcvd = mq.TLO.DanNet(peer).O(query).Received() or 0
				return rcvd > 0
			end
		)
	end
    return mq.TLO.DanNet(peer).O(query)()
end

function dannet.Unobserve(peer, query)
	if mq.TLO.DanNet(peer).OSet(query)() then
    	mq.cmdf('/dobserve %s -q "%s" -drop', peer, query)
	end
end

return dannet