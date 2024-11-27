local mq = require('mq')
local str = require('str')
local mychar = require('mychar')
local co = require('co')
require('actions.s_bardtwist')


local songbot = {}


--
-- Globals
--

local actionqueue = {}

local State = {}
local Config = {}
local Paused = false
local PauseUntil = 0
local LastTwistAt = 0


--
-- Functions
--

local function log(msg)
	print('(songbot) ' .. msg)
end

local function interrupt()
	mq.cmd('/twist clear')
	co.delay(250)
end

local function check_twist(order)
	if not State.IsCrowdControlActive and not State.IsBardCastActive then
		local gem_order = {}
		for i,spell_key in ipairs(order) do
			gem_order[i] = Config.SpellBar.GemBySpellKey(spell_key)
		end

		local not_what_we_want = false
		if mq.TLO.Twist.Twisting() then
			local current_songs = str.Split(str.Trim(mq.TLO.Twist.List()), ' ')
			if #order ~= #current_songs then
				not_what_we_want = true
			else
				for i,v in ipairs(current_songs) do
					local gem = tonumber(v)
					local expected_gem = gem_order[i]
					if gem ~= expected_gem then
						not_what_we_want = true
						break
					end
				end
			end
		else
			not_what_we_want = true
		end

		if not_what_we_want then
			--interrupt()
			actionqueue.AddUnique(
				ScpBardTwist(
					gem_order,
					40
				)
			)
		end

		-- if not mq.TLO.Twist.Twisting() and LastTwistAt + 2000 < mq.gettime() then
		-- 	local cmd = '/twist'
		-- 	for i,gem in ipairs(gem_order) do
		-- 		cmd = cmd .. ' ' .. gem
		-- 	end
		-- 	mq.cmd(cmd)
		-- 	LastTwistAt = mq.gettime()
		-- end
	end
end

local function do_twisting()
	if mychar.InCombat() then
		check_twist(Config.Twist.CombatOrder())
	else
		check_twist(Config.Twist.Order())
	end
end

--
-- Init
--

function songbot.Init(state, cfg, aq)
	State = state
	Config = cfg
	actionqueue = aq

	mq.bind(
		'/dbcq',
		function(...)
			local args = { ... }
			if #args > 0 then
				if args[1] == 'pause' then
					local timer = tonumber(args[2]) or 20
					PauseUntil = mq.gettime() + timer * 1000
				end
			else
				log('status is up')
			end
		end
	)
end


---
--- Main Loop
---

function songbot.Run()
	log('Up and running')
	while true do
		if PauseUntil ~= 0 and not Paused then
			Paused = true
			local seconds = (PauseUntil - mq.gettime()) / 1000
			log('Pausing for ' .. seconds .. ' seconds')
		end

		if State.Mode ~= 1 and not Paused then
			do_twisting()
		else
			if mq.gettime() >= PauseUntil then
				Paused = false
				PauseUntil = 0
				log('Resuming')
			end
		end

		co.yield()
	end
end

return songbot