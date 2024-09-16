local mq = require('mq')
local co = require('co')
local str= require('str')
local mychar = require('mychar')


local tetherbot = {}

--
-- Globals
--

local Config = {}


--
-- Functions
--

local function log(msg)
	print('(tetherbot) ' .. msg)
end

local function in_camp()
	return mq.TLO.DaveBot.Tether.Status() == 'C'
end

local function nav_to_camp()
	mq.cmd('/nav loc ' .. mq.TLO.DaveBot.Tether.Detail() .. ' log=off')
end

local function nav_to_id()
	local id = tonumber(mq.TLO.DaveBot.Tether.Detail())
	mq.cmd('/target id ' .. id)
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
			if in_camp() then
				nav_to_camp()
			end
		elseif args[1]:lower() == 'none' or args[1]:lower() == 'off' then
			mq.TLO.DaveBot.Tether.Clear()
			log('Clearing tether')
		elseif args[1]:lower() == 'camp' then
			mq.TLO.DaveBot.Tether.Camp()
			log('Camp set')
		else
			local id = mq.TLO.Spawn(args[1]).ID()
			if id == nil or id == 0 then
				mq.TLO.DaveBot.Tether.Clear()
				log('Could not find spawn: ' .. args[1])
			else
				mq.TLO.DaveBot.Tether.Follow(id)
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
	if mq.TLO.DaveBot.Tether.Status() ~= 'N' then
		if in_camp() then
			if Config:Tether():ModeIsActive() and not mq.TLO.Navigation.Active() and not mychar.InCombat() and mq.TLO.DaveBot.MyChar.HasNotMovedFor() > Config:Tether():ReturnTimer() then
				local distance = mq.TLO.Math.Distance(mq.TLO.DaveBot.Tether.Detail())()
				if distance > Config:Tether():CampMaxDistance() then
					nav_to_camp()
				end
			end
		else
			local id = tonumber(mq.TLO.DaveBot.Tether.Detail())
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

function tetherbot.Init(cfg)
	Config = cfg

	mq.bind('/dbtether', callback_dbtether)

	log('Initialized')
end


---
--- Main Loop
---

function tetherbot.Run()
	while true do
		do_tether()

		co.yield()
	end
end


return tetherbot