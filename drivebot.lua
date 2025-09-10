local mq = require('mq')
local co = require('co')


local drivebot = {}


--
-- Globals
--

local actionqueue = {}

local State = {}
local Config = {}

local Queue = {}

--
-- Functions
--

local function log(msg)
	print('(drivebot) ' .. msg)
end

local function file_exists(name)
	local f = io.open(name, "r")
	return f ~= nil and io.close(f)
end

local function path_from_array(arr, idx, prefix)
	local pfx = prefix or mq.TLO.MacroQuest.Path() .. '\\lua\\eq-davebot\\drive'
	local i = idx or 1
	local file_test = pfx .. '\\' .. arr[i] .. '.lua'
	if file_exists(file_test) then
		local args = {}
		table.move(arr, i + 1, #arr, 1, args)
		return file_test, args
	end
	if #arr >= i + 1 then
		return path_from_array(arr, i + 1, pfx .. '\\' .. arr[i])
	else
		return '', {}
	end
end

local function callback_drive(...)
	local args = { ... }
	if #args > 0 then
		local to_execute, ps = path_from_array(args)
		if to_execute ~= '' then
			-- log('Executing from ' .. to_execute)
			local f, err = loadfile (to_execute)
			if f == nil then
				print(err)
			else
				local package = f()
				table.insert(Queue, { package=package, ps=ps })
			end
		end
	else
		log('drivebot is up')
	end
end

local function do_drive()
	if #Queue > 0 then
		local drive = table.remove(Queue)
		if drive.package.Init ~= nil then
			drive.package.Init(State, Config, actionqueue)
		end
		---@diagnostic disable-next-line: deprecated
		drive.package.Run(unpack(drive.ps))
	end
end


--
-- Init
--

function drivebot.Init(state, cfg, aq)
	State = state
	Config = cfg
	actionqueue = aq

	mq.bind('/drive', callback_drive)
end


---
--- Main Loop
---

function drivebot.Run()
	mq.cmd('/netbots on')
	mq.cmd('/netbots grab=on')
	mq.cmd('/netbots send=on')
	mq.cmd('/netbots ext=on')
	log('Up and running')
	while true do
		do_drive()
		co.yield()
	end
end

return drivebot