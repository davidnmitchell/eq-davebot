local mq = require('mq')
local co = require('co')
local str = require('str')
local group = require('group')


local teameventbot = {}

--
-- Globals
--

local Config = {}
local Ini = {}


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

local function callback_pull_end(line, who, mob)
	if group.IsPuller(who) then
		local cmd = str.Trim(Config:TeamEvents():OnPullEnd() or '')
		if cmd:len() > 0 then
			mq.cmd(cmd)
		end
	end
end

local function callback_pre_engage(line, who, mob)
	if group.IsMainAssist(who) then
		local cmd = str.Trim(Config:TeamEvents():OnPreEngage() or '')
		if cmd:len() > 0 then
			mq.cmd(cmd)
		end
	end
end

local function callback_engaging(line, who, mob)
	if group.IsMainAssist(who) then
		local cmd = str.Trim(Config:TeamEvents():OnEngage() or '')
		if cmd:len() > 0 then
			mq.cmd(cmd)
		end
	end
end


--
-- Init
--

function teameventbot.Init(cfg)
	Config = cfg
	Ini = cfg._ini

	mq.event('teamevent1', "#1# tells the group, 'Pulling #2#'", callback_pull_start)
	mq.event('teamevent2', "#1# tells the group, 'Arrived back at camp'", callback_pull_end)
	mq.event('teamevent3', "#1# tells the group, 'Waiting to engage #2#'", callback_pre_engage)
	mq.event('teamevent4', "#1# tells the group, 'Engaging #2#'", callback_engaging)
	
	log('Initialized')
end


---
--- Main Loop
---

function teameventbot.Run()
	while true do
		co.yield()
	end
end


return teameventbot