local mq = require('mq')
local common = require('common')
local co = require('co')
local str = require('str')

local netbots = {}

function netbots.Peers()
	return str.Split(mq.TLO.NetBots.Client(), ' ')
end

function netbots.PeerIds()
	local value = {}
	for i, name in ipairs(netbots.Peers()) do
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
		if id == mq.TLO.NetBots(name).ID() then
			return name
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

-- common.PrintTable(netbots.PeerIds())

-- print(mq.TLO.NetBots('Vubelar').Buff())
-- print(mq.TLO.Spell(261)())
-- print(mq.TLO.Spell(2570)())
return netbots