local mq = require('mq')
local common = require('common')
local co = require('co')
local str = require('str')

local netbots = {}

function netbots.Peers()
	---@diagnostic disable-next-line: missing-parameter
	return str.Split(mq.TLO.NetBots.Client(), ' ')
end

function netbots.PeerIds()
	local value = {}
	for i, name in ipairs(netbots.Peers()) do
		---@diagnostic disable-next-line: undefined-field
		table.insert(value, tonumber(mq.TLO.NetBots(name).ID()))
	end
	return value
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
	for i, name in ipairs(netbots.Peers()) do
		---@diagnostic disable-next-line: undefined-field
		if id == mq.TLO.NetBots(name).ID() then
			return name
		end
	end
	return ''
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
	if peer:len() > 0 then
		return mq.TLO.NetBots(peer).TargetID()
	end
	return 0
end

-- function netbots.PetTargetIdByPeerId(id)
-- 	local peer = netbots.PeerById(id)
-- 	if peer:len() > 0 then
-- 		return mq.TLO.NetBots(peer).TargetID
-- 	end
-- 	return 0
-- end

return netbots