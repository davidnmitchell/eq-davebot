local mq = require('mq')
local co = require('co')
local mychar = require('mychar')
local group = require('group')
require('eqclass')
require('actions.s_engage')


local meleebot = {}


--
-- Globals
--

local actionqueue = {}

local State = {}
local Config = {}
local MyClass = EQClass:new()


--
-- Functions
--

local function log(msg)
	print('(meleebot) ' .. msg)
end

local function Engaged()
	return mq.TLO.Me.Combat()
end


local function do_melee()
	if mychar.InCombat() and not State.InCombat then
		State.InCombat = true
		if MyClass.HasSpells then
			log('In combat, wiping actionqueue')
			actionqueue.Wipe()
		end
	end

	if not mychar.InCombat() and State.InCombat then
		State.InCombat = false
		if State.TetherStatus == 'C' then
			actionqueue.AddUnique(
				ScpNavToCamp(
					40,
					false
				)
			)
		elseif State.TetherStatus == 'P' then
			State.TetherResume()
		end
	end

	if State.TetherStatus ~= 'R' then
		if mychar.InCombat() and not Engaged() then
			local group_assist_target = mq.TLO.Me.GroupAssistTarget()
			if group_assist_target then
				---@diagnostic disable-next-line: undefined-field
				if mq.TLO.Me.GroupAssistTarget.PctHPs() < Config.Melee.EngageTargetHPs() and mq.TLO.Me.GroupAssistTarget.Distance() < Config.Melee.EngageTargetDistance() then
					if State.TetherStatus == 'F' then
						State.TetherPause()
					end
					actionqueue.AddUnique(
						ScpEngage(
							---@diagnostic disable-next-line: undefined-field
							mq.TLO.Me.GroupAssistTarget.ID(),
							30
						)
					)
				end
			end

			if group.MainAssistCheck(60000) then
				log('Group main assist is not set')
			end
		end

		if mychar.InCombat() and Engaged() and (not mq.TLO.Target() or mq.TLO.Target() ~= mq.TLO.Me.GroupAssistTarget()) then
			mq.cmd('/attack off')
		end
	elseif Engaged() then
		mq.cmd('/attack off')
	end
end


--
-- Init
--

function meleebot.Init(state, cfg, aq)
	State = state
	Config = cfg
	actionqueue = aq
end


---
--- Main Loop
---

function meleebot.Run()
	log('Up and running')
	while true do
		if State.Mode ~= 1 then
			do_melee()
		end
		co.yield()
	end
end

return meleebot