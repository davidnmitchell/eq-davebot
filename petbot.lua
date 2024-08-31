local mq = require('mq')
local spells = require('spells')
local mychar = require('mychar')
local heartbeat = require('heartbeat')
require('eqclass')
require('botstate')
require('config')


--
-- Globals
--

local ProcessName = 'petbot'
local MyClass = EQClass:new()
local State = BotState:new(false, ProcessName, false, false)
local Config = PetConfig:new()
local SpellBar = SpellBarConfig:new()

local Running = true


--
-- Functions
--

local function log(msg)
	print('(' .. ProcessName .. ') ' .. msg)
end

local function CastPet()
	local gem = SpellBar:FirstOpenGem(State)
	if gem ~= 0 then
		local spell = spells.ReferenceSpell('Pet,Sum: ' .. Config:Type(State) .. ',Self')
		spells.QueueSpellIfNotQueued(spell, 'gem' .. gem, mq.TLO.Me.ID(), 'Casting pet: ' .. spell, Config:MinMana(State), 0, 1, 8)
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

		if not i_have_a_pet and Config:AutoCast(State) and not mychar.InCombat() then
			CastPet()
		end

		if i_have_a_pet and Config:AutoAttack(State) and mychar.InCombat() and not mq.TLO.Pet.Combat() and group_assist_target ~= nil then
			---@diagnostic disable-next-line: undefined-field
			local pct_hps = mq.TLO.Me.GroupAssistTarget.PctHPs()
			---@diagnostic disable-next-line: undefined-field
			local distance = mq.TLO.Me.GroupAssistTarget.Distance()
			if pct_hps and pct_hps < Config:EngageTargetHPs(State) and distance and distance < Config:EngageTargetDistance(State) then
				mq.cmd('/target ' .. group_assist_target)
				mq.delay(500)
				mq.cmd('/pet attack')
			end
		end
		if i_have_a_pet and Config:AutoAttack(State) and mychar.InCombat() and mq.TLO.Pet.Combat() and (not mq.TLO.Pet.Target() or mq.TLO.Pet.Target() ~= mq.TLO.Me.GroupAssistTarget()) then
			mq.cmd('/pet as you were')
		end

		Config:Reload(10000)
		SpellBar:Reload(10000)

		heartbeat.SendHeartBeat(ProcessName)
		mq.delay(10)
	end
end


--
-- Execution
--

main()
