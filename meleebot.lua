local mq = require('mq')
local spells = require('spells')
local mychar = require('mychar')
local group = require('group')
local heartbeat = require('heartbeat')
require('eqclass')
require('config')


--
-- Globals
--

local ProcessName = 'meleebot'
local MyClass = EQClass:new()
local Config = Config:new(ProcessName)

local Running = true
local InCombat = false


--
-- Functions
--

local function log(msg)
	print('(' .. ProcessName .. ') ' .. msg)
end

local function Engaged()
	return mq.TLO.Me.Combat()
end


--
-- Main
--

local function main()
	while Running == true do
		mq.doevents()

		local enabled = Config:Melee():Enabled()

		if mychar.InCombat() and not InCombat then
			InCombat = true
			if MyClass.HasSpells then
				log('In combat, wiping spell queue')
				spells.WipeQueue()
			end
		end

		if not mychar.InCombat() and InCombat then
			InCombat = false
			if enabled then
				mq.cmd('/makecamp return')
			end
		end

		if enabled and mychar.InCombat() and not Engaged() then
			local group_assist_target = mq.TLO.Me.GroupAssistTarget()
			if group_assist_target then
				---@diagnostic disable-next-line: undefined-field
				if mq.TLO.Me.GroupAssistTarget.PctHPs() < Config:Melee():EngageTargetHPs() and mq.TLO.Me.GroupAssistTarget.Distance() < Config:Melee():EngageTargetDistance() then
					mq.cmd('/g (' .. ProcessName .. ')Engaging ' .. group_assist_target)
					mq.cmd('/target ' .. group_assist_target)
					mq.delay(250)
					mq.cmd('/stand')
					mq.cmd('/attack on')
				end
			end

			if group.MainAssistCheck(60000) then
				log('Group main assist is not set')
			end
		end

		if enabled and mychar.InCombat() and Engaged() and (not mq.TLO.Target() or mq.TLO.Target() ~= mq.TLO.Me.GroupAssistTarget()) then
			mq.cmd('/attack off')
		end

		Config:Reload(10000)

		heartbeat.SendHeartBeat(ProcessName)
		mq.delay(10)
	end
end


--
-- Execution
--

main()
