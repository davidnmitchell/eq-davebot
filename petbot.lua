local mq = require('mq')
local co = require('co')
local spells = require('spells')
local mychar = require('mychar')
require('actions.s_cast')
require('actions.s_petengage')


local petbot = {}


--
-- Globals
--

local actionqueue = {}

local State = {}
local Config = {}


--
-- Functions
--

local function log(msg)
	print('(petbot) ' .. msg)
end

local function CastPet()
	local gem = Config:SpellBar():FirstOpenGem()
	if gem ~= 0 then
		local spell = spells.ReferenceSpell('Pet,Sum: ' .. Config:Pet():Type() .. ',Self')
		actionqueue.AddUnique(
			ScpCast(
				spell,
				'gem' .. gem,
				Config:Pet():MinMana(),
				1,
				nil,
				0,
				nil,
				80
			)
		)
	else
		log('Cannot find open gem to cast pet')
	end
end

local function hps_in_range()
	---@diagnostic disable-next-line: undefined-field
	local pct_hps = mq.TLO.Me.GroupAssistTarget.PctHPs()
	---@diagnostic disable-next-line: undefined-field
	return pct_hps and pct_hps < Config:Pet():EngageTargetHPs() and not mq.TLO.Me.GroupAssistTarget.Dead()
end

local function engage_in_range()
	---@diagnostic disable-next-line: undefined-field
	local distance = mq.TLO.Me.GroupAssistTarget.Distance()
	return distance and distance < Config:Pet():EngageTargetDistance()
end

local function pet_has_wrong_target()
	---@diagnostic disable-next-line: undefined-field
	return mq.TLO.Pet.Target() == nil or mq.TLO.Pet.Target.ID() ~= mq.TLO.Me.GroupAssistTarget.ID()
end

local function do_pet()
	local i_have_a_pet = mq.TLO.Pet() ~= 'NO PET'

	if not i_have_a_pet and Config:Pet():AutoCast() and not mychar.InCombat() then
		CastPet()
	end

	if i_have_a_pet and Config:Pet():AutoAttack() and mychar.InCombat() and not mq.TLO.Pet.Combat() and mq.TLO.Me.GroupAssistTarget() ~= nil and hps_in_range() and engage_in_range() then
		actionqueue.AddUnique(
			ScpPetEngage(
				---@diagnostic disable-next-line: undefined-field
				mq.TLO.Me.GroupAssistTarget.ID(),
				35
			)
		)
	end
	---@diagnostic disable-next-line: undefined-field
	if i_have_a_pet and Config:Pet():AutoAttack() and mychar.InCombat() and mq.TLO.Pet.Combat() and (pet_has_wrong_target() or not hps_in_range()) then
		log('Telling pet to back off')
		mq.cmd('/pet back')
	end
end


--
-- Init
--

function petbot.Init(state, cfg, aq)
	State = state
	Config = cfg
	actionqueue = aq
end


---
--- Main Loop
---

function petbot.Run()
	log('Up and running')
	while true do
		do_pet()
		co.yield()
	end
end

return petbot