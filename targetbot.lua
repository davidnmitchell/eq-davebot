local mq = require('mq')
local co = require('co')
require('actions.s_target')


local targetbot = {}


--
-- Globals
--

local actionqueue = {}

local State = {}
local Config = {}


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
					local last_npc = State:LastTargetOf(
						function(id)
							return mq.TLO.Spawn(id).Type() == 'NPC'
						end
					)
					if last_npc > 0 then
						actionqueue.Add(
							ScpTarget(
								last_npc,
								40
							)
						)
					end
					-- for i, h_id in ipairs(State.TargetHistory) do
					-- 	if mq.TLO.Spawn(h_id).Type() == 'NPC' then
					-- 		actionqueue.Add(
					-- 			ScpTarget(
					-- 				h_id,
					-- 				40
					-- 			)
					-- 		)
					-- 	end
					-- end
				end
			end
		elseif args[1] == 'history' then
			for i, h_id in ipairs(State.TargetHistory) do
				log(mq.TLO.Spawn(h_id).Name())
			end
		end
	else
		log('targetbot is up')
	end
end

local function do_history()
	if #State.TargetHistory < 1 or State.TargetHistory[1] ~= mq.TLO.Target.ID() then
		table.insert(State.TargetHistory, 1, mq.TLO.Target.ID())
	end
	while #State.TargetHistory > 10 do
		table.remove(State.TargetHistory, #State.TargetHistory)
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

function targetbot.Init(state, cfg, aq)
	State = state
	Config = cfg
	actionqueue = aq

	mq.bind('/dbtarget', callback_dbt)
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