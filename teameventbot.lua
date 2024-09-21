local mq = require('mq')
local co = require('co')
local str = require('str')
local group = require('group')


local teameventbot = {}

--
-- Globals
--

local State = {}
local Config = {}


--
-- Functions
--

local function log(msg)
	print('(teameventbot) ' .. msg)
end


--
-- Events
--

local function callback_pull_start(line, who, mob)
	if group.IsPuller(who) then
		local cmd = str.Trim(Config:TeamEvents():OnPullStart() or '')
		if cmd:len() > 0 then
			mq.cmd(cmd)
		end
	end
end

local function callback_pull_start_me(line, mob)
	callback_pull_start(line, mq.TLO.Me.Name(), mob)
end

local function callback_pull_end(line, who, mob)
	if group.IsPuller(who) then
		local cmd = str.Trim(Config:TeamEvents():OnPullEnd() or '')
		if cmd:len() > 0 then
			mq.cmd(cmd)
		end
	end
end

local function callback_pull_end_me(line, mob)
	callback_pull_end(line, mq.TLO.Me.Name(), mob)
end

local function callback_pre_engage(line, who, mob)
	if group.IsMainAssist(who) then
		local cmd = str.Trim(Config:TeamEvents():OnPreEngage() or '')
		if cmd:len() > 0 then
			mq.cmd(cmd)
		end
	end
end

local function callback_pre_engage_me(line, mob)
	callback_pre_engage(line, mq.TLO.Me.Name(), mob)
end

local function callback_engaging(line, who, mob)
	if group.IsMainAssist(who) then
		local cmd = str.Trim(Config:TeamEvents():OnEngage() or '')
		if cmd:len() > 0 then
			mq.cmd(cmd)
		end
	end
end

local function callback_engaging_me(line, mob)
	callback_engaging(line, mq.TLO.Me.Name(), mob)
end


--
-- Init
--

function teameventbot.Init(state, cfg)
	State = state
	Config = cfg

	mq.event('teamevent1', "#1# tells the group, 'Pulling #2#'", callback_pull_start)
	mq.event('teamevent1.1', "#1# tells the group, in #*#, 'Pulling #2#'", callback_pull_start)
	mq.event('teamevent1.2', "You tell your party, 'Pulling #1#'", callback_pull_start_me)
	mq.event('teamevent2', "#1# tells the group, 'Arrived back at camp'", callback_pull_end)
	mq.event('teamevent2.1', "#1# tells the group, in #*#, 'Arrived back at camp'", callback_pull_end)
	mq.event('teamevent2.2', "You tell your party, 'Arrived back at camp'", callback_pull_end_me)
	mq.event('teamevent3', "#1# tells the group, 'Waiting to engage #2#'", callback_pre_engage)
	mq.event('teamevent3.1', "#1# tells the group, in #*#, 'Waiting to engage #2#'", callback_pre_engage)
	mq.event('teamevent3.2', "You tell your party, 'Waiting to engage #1#'", callback_pre_engage_me)
	mq.event('teamevent4', "#1# tells the group, 'Engaging #2#'", callback_engaging)
	mq.event('teamevent4.1', "#1# tells the group, in #*#, 'Engaging #2#'", callback_engaging)
	mq.event('teamevent4.2', "You tell your party, 'Engaging #1#'", callback_engaging_me)
end


---
--- Main Loop
---

function teameventbot.Run()
	log('Up and running')
	while true do
		co.yield()
	end
end


return teameventbot