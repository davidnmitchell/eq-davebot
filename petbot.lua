local mq = require('mq')
require('ini')
require('eqclass')
require('botstate')
local spells = require('spells')
local mychar = require('mychar')


function DefaultType()
	local default_type = ''
	if MyClass.Name == 'Magician' then
		default_type = 'Water'
	elseif MyClass.Name == 'Shaman' then
		default_type = 'Warder'
	elseif MyClass.Name == 'Shadow Knight' then
		default_type = 'Undead'
	elseif MyClass.Name == 'Necromancer' then
		default_type = 'Undead'
	elseif MyClass.Name == 'Beastlord' then
		print('Need Beastlord Code')
	elseif MyClass.Name == 'Enchanter' then
		default_type = 'Animation'
	elseif MyClass.Name == 'Wizard' then
		default_type = 'Familiar'
	end
	return default_type
end


--
-- Globals
--

MyClass = EQClass:new()
State = BotState:new('petbot', true, false)

Running = true
AutoCast = false
AutoAttack = false

Type = DefaultType()
Gem = 8
MinMana = 20
EngageTargetHpPct = 95
EngageTargetDistance = 75


--
-- Functions
--

function BuildIni(ini)
	print('Building pet config')

	local options = ini:Section('Pet Options')
	options:WriteBoolean('AutoCast', false)
	options:WriteBoolean('AutoAttack', false)
	options:WriteString('Type', DefaultType())
	options:WriteNumber('Gem', 8)
	options:WriteNumber('MinMana', 20)
	options:WriteNumber('EngageTargetHpPct', 95)
	options:WriteNumber('EngageTargetDistance', 75)
end

function LoadIni(ini)
	AutoCast = ini:Boolean('Pet Options', 'AutoCast', AutoCast)
	AutoAttack = ini:Boolean('Pet Options', 'AutoAttack', AutoAttack)
	Type = ini:String('Pet Options', 'Type', Type)
	Gem = ini:Number('Pet Options', 'Gem', Gem)
	MinMana = ini:Number('Pet Options', 'MinMana', MinMana)
	EngageTargetHpPct = ini:Number('Pet Options', 'EngageTargetHpPct', EngageTargetHpPct)
	EngageTargetDistance = ini:Number('Pet Options', 'EngageTargetDistance', EngageTargetDistance)
end

function Setup()
	local ini = Ini:new()

	if ini:IsMissing('Pet Options', 'AutoCast') then BuildIni(ini) end

	LoadIni(ini)

	print('Petbot loaded')

	return ini
end



function CastPet()
	local spell = spells.ReferenceSpell('Pet,Sum: ' .. Type .. ',Self')
	spells.QueueSpellIfNotQueued(spell, 'gem' .. Gem, mq.TLO.Me.ID(), 'Casting pet: ' .. spell, MinMana, 0, 1, 8)
end

--
-- Main
--

local function main()
	local ini = Setup()
	local nextload = mq.gettime() + 10000

	while Running == true do
		mq.doevents()

		local i_have_a_pet = mq.TLO.Pet() ~= 'NO PET'
		local group_assist_target = mq.TLO.Me.GroupAssistTarget()

		if not i_have_a_pet and AutoCast and not mychar.InCombat() then
			CastPet()
		end

		if i_have_a_pet and AutoAttack and mychar.InCombat() and not mq.TLO.Pet.Combat() and group_assist_target ~= nil then
			local pct_hps = mq.TLO.Me.GroupAssistTarget.PctHPs()
			local distance = mq.TLO.Me.GroupAssistTarget.Distance()
			if pct_hps and pct_hps < EngageTargetHpPct and distance and distance < EngageTargetDistance then
				mq.cmd('/target ' .. group_assist_target)
				mq.delay(500)
				mq.cmd('/pet attack')
			end
		end
		if i_have_a_pet and AutoAttack and mychar.InCombat() and mq.TLO.Pet.Combat() and (not mq.TLO.Pet.Target() or mq.TLO.Pet.Target() ~= mq.TLO.Me.GroupAssistTarget()) then
			mq.cmd('/pet as you were')
		end

		local time = mq.gettime()
		if time >= nextload then
			LoadIni(ini)
			nextload = time + 10000
		end
		mq.delay(10)
	end
end


--
-- Execution
--

main()
