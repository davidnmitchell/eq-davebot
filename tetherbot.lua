local mq = require('mq')
local co = require('co')
local str= require('str')
local mychar = require('mychar')
require('actions.s_navtocamp')


local tetherbot = {}

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
	print('(tetherbot) ' .. msg)
end

local function have_camp()
	return State.TetherStatus == 'C'
end

local function nav_to_camp()
	actionqueue.AddUnique(
		ScpNavToCamp(
			30,
			false
		)
	)
	-- mq.cmd('/nav loc ' .. State.TetherDetail .. ' log=off')
end

-- TODO: Action this
local function nav_to_id()
	local id = tonumber(State.TetherDetail) or 0
	mq.TLO.Spawn(id).DoTarget()
	co.delay(2000, function() return mq.TLO.Target.ID() == id end)
	mq.cmd('/nav target log=off')
end

local function location(mqloc)
	local parts = str.Split(mqloc, ',')
	local y = tonumber(str.Trim(parts[1]))
	local x = tonumber(str.Trim(parts[2]))
	local z = tonumber(str.Trim(parts[3]))
	return x,y,z
end

local function callback_dbtether(...)
	local args = { ... }
	if #args > 0 then
		if args[1]:lower() == 'return' then
			if have_camp() then
				nav_to_camp()
			end
		elseif args[1]:lower() == 'none' or args[1]:lower() == 'off' then
			State:TetherClear()
			log('Clearing tether')
		elseif args[1]:lower() == 'camp' then
			State:TetherCamp()
			log('Camp set')
		else
			local id = mq.TLO.Spawn(args[1]).ID()
			if id == nil or id == 0 then
				State:TetherClear()
				log('Could not find spawn: ' .. args[1])
			else
				State:TetherFollow(id)
				log('Following id ' .. id)
			end
		end
	else
		log('tetherbot is up')
	end
end

--
-- To Quiet EasyFind, there is a log setting in config/EasyFind.yaml
--

local function do_tether()
	if State.TetherStatus ~= 'N' then
		if have_camp() then
			if Config:Tether():ModeIsActive() and not mq.TLO.Navigation.Active() and not mychar.InCombat() and State:MyCharHasNotMovedFor() > Config:Tether():ReturnTimer() then
				local distance = mq.TLO.Math.Distance(State.TetherDetail)()
				if distance > Config:Tether():CampMaxDistance() then
					nav_to_camp()
				end
			end
		else
			local id = tonumber(State.TetherDetail)
			if id ~= nil and Config:Tether():ModeIsActive() and not mq.TLO.Navigation.Active() then
				local distance = mq.TLO.Spawn(id).Distance3D()
				if distance ~= nil and distance > Config:Tether():FollowMaxDistance() then
					nav_to_id()
				end
			end
		end
	end
end


--
-- Init
--

function tetherbot.Init(state, cfg, aq)
	State = state
	Config = cfg
	actionqueue = aq

	mq.bind('/dbtether', callback_dbtether)
end


---
--- Main Loop
---

function tetherbot.Run()
	log('Up and running')
	while true do
		do_tether()
		co.yield()
	end
end


return tetherbot