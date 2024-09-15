local mq = require('mq')
local str = require('str')
local mychar = require('mychar')
local co = require('co')


local songbot = {}


--
-- Globals
--

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
	if not Config:State():CrowdControlActive() and not Config:State():BardCastActive() then
		local gem_order = {}
		for i,spell_key in ipairs(order) do
			gem_order[i] = Config:SpellBar():GemBySpellKey(spell_key)
		end

		if mq.TLO.Twist.Twisting() then
			local current_songs = str.Split(str.Trim(mq.TLO.Twist.List()), ' ')
			if #order ~= #current_songs then
				interrupt()
			else
				for i,v in ipairs(current_songs) do
					local gem = tonumber(v)
					local expected_gem = gem_order[i]
					if gem ~= expected_gem then
						interrupt()
						break
					end
				end
			end
		end

		if not mq.TLO.Twist.Twisting() and LastTwistAt + 2000 < mq.gettime() then
			local cmd = '/twist'
			for i,gem in ipairs(gem_order) do
				cmd = cmd .. ' ' .. gem
			end
			mq.cmd(cmd)
			LastTwistAt = mq.gettime()
		end
	end
end

local function do_twisting()
	if mychar.InCombat() then
		check_twist(Config:Twist():CombatOrder())
	else
		check_twist(Config:Twist():Order())
	end
end

--
-- Init
--

function songbot.Init(cfg)
	Config = cfg

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
	while true do
		if PauseUntil ~= 0 and not Paused then
			Paused = true
			local seconds = (PauseUntil - mq.gettime()) / 1000
			log('Pausing for ' .. seconds .. ' seconds')
		end

		if not Paused then
			if Config:Twist():Enabled() then
				do_twisting()
			end
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