local mq = require('mq')
local array = require('array')
local str = require('str')

local netbots = {}

function netbots.Peers()
	---@diagnostic disable-next-line: missing-parameter
	local peers = str.Split(mq.TLO.NetBots.Client(), ' ')
	return peers
end

function netbots.IsPeer(name)
	return array.HasValue(netbots.Peers(), name)
end

function netbots.PeerIds()
	---@diagnostic disable-next-line: undefined-field
	return array.Mapped(netbots.Peers(), function(name) return tonumber(mq.TLO.NetBots(name).ID()) end)
end

function netbots.PeerPetIds()
	local value = {}
	for i, name in ipairs(netbots.Peers()) do
		local id = mq.TLO.NetBots(name).PetID()
		if id ~= nil and id ~= 0 then
			table.insert(value, tonumber(id))
		end
	end
	return value
end

function netbots.PeerById(id)
	---@diagnostic disable-next-line: undefined-field
	return array.FirstOrNil(netbots.Peers(), function(name) return id == mq.TLO.NetBots(name).ID() end)
end

function netbots.PeerByName(name)
	for i, peer in ipairs(netbots.Peers()) do
		if peer:lower() == name:lower() then
			return peer
		end
	end
	return ''
end

function netbots.PeerByPetId(id)
	for i, name in ipairs(netbots.Peers()) do
		if id == mq.TLO.NetBots(name).PetID() then
			return name
		end
	end
	return ''
end

function netbots.TargetIdByPeerId(id)
	local peer = netbots.PeerById(id)
	if peer ~= nil then
		return mq.TLO.NetBots(peer).TargetID()
	end
	return 0
end

return netbots