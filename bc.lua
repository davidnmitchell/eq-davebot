local mq = require('mq')
local co = require('co')
local str = require('str')

local bc = {}

local in_flight = {}

local function callback_server(line, from)
	local prefix = 'QUERY'
	local idx = line:find(prefix)
	local q = str.Trim(line:sub(idx + #prefix + 1, -1))
	local value = assert(load('return mq.TLO.' .. q .. '()'))() or 'nil'
	mq.cmd('/squelch /bct ' .. from .. ' RESPONSE ' .. q .. '|' .. value)
end

local function callback_client(line, from)
	local prefix = 'RESPONSE'
	local idx = line:find(prefix)
	local response = str.Trim(line:sub(idx + #prefix + 1, -1))
	local parts = str.Split(response, '|')
	in_flight[from .. ':' .. parts[1]] = parts[2]
end

function bc.InitServer()
	mq.event('netquery_server', '[#1#(msg)] QUERY #*#', callback_server)
end

function bc.InitClient()
	mq.event('netquery_client', '[#1#(msg)] RESPONSE #*#', callback_client)
end

function bc.Query(name, query, timeout)
	local key = name .. ':' .. query
	in_flight[key] = 'SENT'
	mq.cmd('/squelch /bct ' .. name .. ' QUERY ' .. query)
	co.delay(
		timeout or 20000,
		function()
			return in_flight[key] ~= 'SENT'
		end
	)
	if in_flight[key] == 'SENT' then
		return ''
	else
		if in_flight[key] == 'nil' then
			return nil
		end
		return in_flight[key]
	end
end

function bc.Peers()
	return str.Split(mq.TLO.EQBC.Names(), ' ')
end

function bc.PeerIds()
	local value = {}
	for i, name in ipairs(bc.Peers()) do
		value[name] = tonumber(bc.Query(name, 'Me.ID', 5000))
	end
	return value
end

function bc.IsAPeer(id)
	for i, peer_name in ipairs(bc.Peers()) do
		if id == mq.TLO.Spawn(peer_name).ID() then
			return true
		end
	end
	return false
end

return bc