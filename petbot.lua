local mq = require('mq')
local co = require('co')
local spells = require('spells')
local mychar = require('mychar')
local heartbeat = require('heartbeat')
require('eqclass')
require('config')


--
-- Globals
--

local ProcessName = 'petbot'
local MyClass = EQClass:new()
local Config = Config:new(ProcessName)

local Running = true


--
-- Functions
--

local function log(msg)
	print('(' .. ProcessName .. ') ' .. msg)
end

local function CastPet()
	local gem = Config:SpellBar():FirstOpenGem()
	if gem ~= 0 then
		local spell = spells.ReferenceSpell('Pet,Sum: ' .. Config:Pet():Type() .. ',Self')
		spells.QueueSpellIfNotQueued(spell, 'gem' .. gem, mq.TLO.Me.ID(), 'Casting pet: ' .. spell, Config:Pet():MinMana(), 0, 1, 80)
	else
		log('Cannot find open gem to cast pet')
	end
end

--
-- Main
--

local function main()

	while Running == true do
		mq.doevents()

		local i_have_a_pet = mq.TLO.Pet() ~= 'NO PET'
		local group_assist_target = mq.TLO.Me.GroupAssistTarget()

		if not i_have_a_pet and Config:Pet():AutoCast() and not mychar.InCombat() then
			CastPet()
		end

		if i_have_a_pet and Config:Pet():AutoAttack() and mychar.InCombat() and not mq.TLO.Pet.Combat() and group_assist_target ~= nil then
			---@diagnostic disable-next-line: undefined-field
			local pct_hps = mq.TLO.Me.GroupAssistTarget.PctHPs()
			---@diagnostic disable-next-line: undefined-field
			local distance = mq.TLO.Me.GroupAssistTarget.Distance()
			if pct_hps and pct_hps < Config:Pet():EngageTargetHPs() and distance and distance < Config:Pet():EngageTargetDistance() then
				mq.cmd('/target ' .. group_assist_target)
				co.delay(500, function() return mq.TLO.Target.ID() == group_assist_target end)
				log('Telling pet to attack')
				mq.cmd('/pet attack')
			end
		end
		if i_have_a_pet and Config:Pet():AutoAttack() and mychar.InCombat() and mq.TLO.Pet.Combat() and (not mq.TLO.Pet.Target() or mq.TLO.Pet.Target() ~= mq.TLO.Me.GroupAssistTarget() or mq.TLO.Me.GroupAssistTarget.PctHPs() > Config:Pet():EngageTargetHPs()) then
			log('Telling pet to back off')
			mq.cmd('/pet as you were')
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
