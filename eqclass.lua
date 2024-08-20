local mq = require('mq')


EQClass = {}
EQClass.__index = EQClass

function EQClass:new(name)
	local obj = {}
	setmetatable(obj, self)

	obj.name = name or mq.TLO.Me.Class.Name()

	obj.IsHealer = obj.name == 'Shaman' or obj.name == 'Druid' or obj.name == 'Cleric'
	obj.HasGroupHeals = obj.name == 'Cleric' or obj.name == 'Paladin'
	obj.IsCaster = obj.name == 'Wizard' or obj.name == 'Magician' or obj.name == 'Necromancer' or obj.name == 'Enchanter'
	obj.IsHybrid = obj.name == 'Ranger' or obj.name == 'Paladin' or obj.name == 'Shadow Knight' or obj.name == 'Beastlord'
	obj.HasSpells = obj.IsHealer or obj.IsHybrid or obj.IsCaster

	obj.IsDebuffer = obj.name == 'Shaman' or obj.name == 'Enchanter'
	obj.IsCrowdController = obj.name == 'Bard' or obj.name == 'Enchanter'
	obj.IsMelee = obj.name == 'Ranger' or obj.name == 'Monk' or obj.name == 'Bard' or obj.name == 'Rogue' or obj.name == 'Berserker' or obj.name == 'Paladin' or obj.name == 'Shadow Knight' or obj.name == 'Warrior'
	obj.HasPet = obj.name == 'Shaman' or obj.name == 'Magician' or obj.name == 'Necromancer' or obj.name == 'Beastlord' or obj.name == 'Enchanter' or obj.name == 'Wizard' or obj.name == 'Shadow Knight'
	obj.IsBard = obj.name == 'Bard'

	return obj
end
