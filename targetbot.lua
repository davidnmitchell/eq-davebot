local mq = require('mq')
local mychar = require('mychar')
local co = require('co')

local targetbot = {}


--
-- Globals
--

local State = {}
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


-- --
-- -- TLO
-- --

-- function targetbot.TLOData()
-- 	return { LockOwner = '', LockTimeout = 0 }
-- end

-- function targetbot.TLOType()
-- 	return mq.DataType.new('TargetType', {
-- 		Members = {
-- 			MyLock = function(owner, target)
-- 				return 'bool', target.LockOwner == owner and target.LockTimeout > mq.gettime()
-- 			end
-- 		},

-- 		Methods = {
-- 			AcquireLock = function(owner, target)
-- 				if target.LockOwner == '' or target.LockOwner == owner or target.LockTimeout <= mq.gettime() then
-- 					target.LockOwner = owner
-- 					target.LockTimeout = mq.gettime() + 1000
-- 				end
-- 			end,
-- 			ReleaseLock = function(owner, target)
-- 				if target.LockOwner == owner and target.LockTimeout > mq.gettime() then
-- 					target.LockOwner = ''
-- 					target.LockTimeout = 0
-- 				end
-- 			end,
-- 			Target = function(id, target)
-- 				mq.cmd('/target id ' .. id)
-- 			end
-- 		},
-- 		ToString = function(_)
-- 			return string.format('')
-- 		end
-- 	})
-- end


--
-- Init
--

function targetbot.Init(state, cfg)
	State = state
	Config = cfg

	mq.bind('/dbt', callback_dbt)
end


---
--- Main Loop
---

function targetbot.Run()
	log('Up and running')
	while true do
		do_history()
		co.yield()
	end
end

return targetbot