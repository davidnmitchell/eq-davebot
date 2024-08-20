local mq = require('mq')
local common = require('common')
local ini = require('ini')
local spells = require('spells')


function DefaultType()
	local default_type = ''
	if MyClassName == 'Magician' then
		default_type = 'Water'
	elseif MyClassName == 'Shaman' then
		default_type = 'Warder'
	elseif MyClassName == 'Shadow Knight' then
		default_type = 'Undead'
	elseif MyClassName == 'Necromancer' then
		default_type = 'Undead'
	elseif MyClassName == 'Beastlord' then
		print('Need Beastlord Code')
	elseif MyClassName == 'Enchanter' then
		default_type = 'Animation'
	elseif MyClassName == 'Wizard' then
		default_type = 'Familiar'
	end
	return default_type
end


--
-- Globals
--

MyClassName = mq.TLO.Me.Class.Name()

Running = true
IniFilename = 'Bot_' .. mq.TLO.Me.CleanName() .. '.ini'

AutoCast = false
AutoAttack = false
Type = DefaultType()
SpellGem = 8
MinPetMana = 20
EngageTargetHpPct = 95
EngageTargetDistance = 75

InCombat = false


--
-- Functions
--

function BuildIni()
	print('Building pet config')
	
	mq.cmd('/ini "' .. IniFilename .. '" PetOptions AutoCast FALSE')
	mq.cmd('/ini "' .. IniFilename .. '" PetOptions AutoAttack FALSE')
	mq.cmd('/ini "' .. IniFilename .. '" PetOptions Type ' .. DefaultType())
	mq.cmd('/ini "' .. IniFilename .. '" PetOptions SpellGem 8')
	mq.cmd('/ini "' .. IniFilename .. '" PetOptions MinPetMana 20')
	mq.cmd('/ini "' .. IniFilename .. '" PetOptions EngageTargetHpPct 95')
	mq.cmd('/ini "' .. IniFilename .. '" PetOptions EngageTargetDistance 75')
end

function Setup()
	if common.empty(IniFilename, 'PetOptions', 'AutoCast') then BuildIni() end
	
	if not common.empty(IniFilename, 'PetOptions', 'AutoCast') then AutoCast = mq.TLO.Ini(IniFilename, 'PetOptions', 'AutoCast')() == 'TRUE' end
	if not common.empty(IniFilename, 'PetOptions', 'AutoAttack') then AutoAttack = mq.TLO.Ini(IniFilename, 'PetOptions', 'AutoAttack')() == 'TRUE' end
	if not common.empty(IniFilename, 'PetOptions', 'Type') then Type = mq.TLO.Ini(IniFilename, 'PetOptions', 'Type')() end
	if not common.empty(IniFilename, 'PetOptions', 'SpellGem') then SpellGem = tonumber(mq.TLO.Ini(IniFilename, 'PetOptions', 'SpellGem')()) end
	if not common.empty(IniFilename, 'PetOptions', 'MinPetMana') then MinPetMana = tonumber(mq.TLO.Ini(IniFilename, 'PetOptions', 'MinPetMana')()) end
	if not common.empty(IniFilename, 'PetOptions', 'EngageTargetHpPct') then EngageTargetHpPct = tonumber(mq.TLO.Ini(IniFilename, 'PetOptions', 'EngageTargetHpPct')()) end
	if not common.empty(IniFilename, 'PetOptions', 'EngageTargetDistance') then EngageTargetDistance = tonumber(mq.TLO.Ini(IniFilename, 'PetOptions', 'EngageTargetDistance')()) end
	
	print('Pet config loaded')
end



function CastPet()
	local spell = common.ReferenceSpell('Pet,Sum: ' .. Type .. ',Self')
	spells.QueueSpellIfNotQueued(spell, 'gem' .. SpellGem, mq.TLO.Me.ID(), 'Casting pet: ' .. spell, MinPetMana, 0, 1, 8)
end

--
-- Main
--

function main()
	Setup()

	while Running == true do
		mq.doevents()

		local i_have_a_pet = mq.TLO.Pet() ~= 'NO PET'
		local group_assist_target = mq.TLO.Me.GroupAssistTarget()

		if not i_have_a_pet and AutoCast and not common.IsGroupInCombat() then
			CastPet()
		end

		if i_have_a_pet and AutoAttack and common.IsGroupInCombat() and not mq.TLO.Pet.Combat() and group_assist_target ~= nil then
			local pct_hps = mq.TLO.Me.GroupAssistTarget.PctHPs()
			local distance = mq.TLO.Me.GroupAssistTarget.Distance()
			if pct_hps and pct_hps < EngageTargetHpPct and distance and distance < EngageTargetDistance then
				mq.cmd('/target ' .. group_assist_target)
				mq.delay(500)
				mq.cmd('/pet attack')
			end
		end
		if i_have_a_pet and AutoAttack and common.IsGroupInCombat() and mq.TLO.Pet.Combat() and (not mq.TLO.Pet.Target() or mq.TLO.Pet.Target() ~= mq.TLO.Me.GroupAssistTarget()) then
			mq.cmd('/pet as you were')
		end
		
		mq.delay(10)
	end
end


--
-- Execution
--

main()
