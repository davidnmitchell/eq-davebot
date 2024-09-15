local mq = require('mq')
local mychar = require('mychar')
local co = require('co')

local targetbot = {}


--
-- Globals
--

local Config = {}
local History = {}


--
-- Functions
--

local function log(msg)
	print('(targetbot) ' .. msg)
end

local function callback_dbt(...)
	local args = { ... }
	if #args > 0 then
		if args[1] == 'target' then
			if args[2] == 'id' then
				local id = tonumber(args[3])
				mq.cmd('/target id ' .. id)
			end
			if args[2] == 'last' then
				if args[3] == 'mob' then
					for i, h_id in ipairs(History) do
						if mq.TLO.Spawn(h_id).Type() == 'NPC' then
							mq.cmd('/target id ' .. h_id)
						end
					end
				end
			end
		elseif args[1] == 'history' then
			for i, h_id in ipairs(History) do
				log(mq.TLO.Spawn(h_id).Name())
			end
		end
	else
		log('targetbot is up')
	end
end

local function do_history()
	if #History < 1 or History[1] ~= mq.TLO.Target.ID() then
		table.insert(History, 1, mq.TLO.Target.ID())
	end
	while #History > 10 do
		table.remove(History, #History)
	end
end


--
-- Init
--

function targetbot.Init(cfg)
	Config = cfg

	mq.bind('/dbt', callback_dbt)
end


---
--- Main Loop
---

function targetbot.Run()
	while true do
		do_history()

		co.yield()
	end
end

return targetbot