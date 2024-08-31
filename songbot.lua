local mq = require('mq')
local str = require('str')
local mychar = require('mychar')
local heartbeat = require('heartbeat')
require('eqclass')
require('botstate')
require('config')



--
-- Globals
--

local ProcessName = 'songbot'
local MyClass = EQClass:new()
local State = BotState:new(false, ProcessName, true, true)
local Config = TwistConfig:new()
local SpellBar = SpellBarConfig:new()

local Running = true


--
-- Functions
--

local function log(msg)
	print('(' .. ProcessName .. ') ' .. msg)
end

function CheckTwist(order)
	if not State:CrowdControlActive() and not State:BardCastActive() then
		local gem_order = {}
		for i,spell_key in ipairs(order) do
			gem_order[i] = SpellBar:GemBySpellKey(State, spell_key)
		end

		if mq.TLO.Twist.Twisting() then
			local current_songs = str.Split(str.Trim(mq.TLO.Twist.List()), ' ')
			for i,v in ipairs(current_songs) do
				local gem = tonumber(v)
				local expected_gem = gem_order[i]
				if gem ~= expected_gem then
					mq.cmd('/twist clear')
					mq.delay(250)
					goto end_loop
				end
			end
			::end_loop::
		end

		if not mq.TLO.Twist.Twisting() then
			local cmd = '/twist'
			for i,gem in ipairs(gem_order) do
				cmd = cmd .. ' ' .. gem
			end
			mq.cmd(cmd)
		end
	end
end


--
-- Main
--

local function main()
	while Running == true do
		mq.doevents()

		if Config:Enabled(State) then
			if mychar.InCombat() then
				CheckTwist(Config:CombatOrder(State))
			else
				CheckTwist(Config:Order(State))
			end
		end

		Config:Reload()

		heartbeat.SendHeartBeat(ProcessName)
		mq.delay(10)
	end
end


--
-- Execution
--

main()
