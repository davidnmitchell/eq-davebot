local mq = require('mq')


EQClass = {}
EQClass.__index = EQClass

function EQClass:new(name)
	local obj = {}
	setmetatable(obj, self)

	obj.Name = name or mq.TLO.Me.Class.Name()

	obj.IsHealer = obj.Name == 'Shaman' or obj.Name == 'Druid' or obj.Name == 'Cleric'
	obj.HasGroupHeals = obj.Name == 'Cleric' or obj.Name == 'Paladin'
	obj.IsCaster = obj.Name == 'Wizard' or obj.Name == 'Magician' or obj.Name == 'Necromancer' or obj.Name == 'Enchanter'
	obj.IsHybrid = obj.Name == 'Ranger' or obj.Name == 'Paladin' or obj.Name == 'Shadow Knight' or obj.Name == 'Beastlord'
	obj.HasSpells = obj.IsHealer or obj.IsHybrid or obj.IsCaster

	obj.IsDebuffer = obj.Name == 'Shaman' or obj.Name == 'Enchanter'
	obj.IsCrowdController = obj.Name == 'Bard' or obj.Name == 'Enchanter'
	obj.IsMelee = obj.Name == 'Ranger' or obj.Name == 'Monk' or obj.Name == 'Bard' or obj.Name == 'Rogue' or obj.Name == 'Berserker' or obj.Name == 'Paladin' or obj.Name == 'Shadow Knight' or obj.Name == 'Warrior'
	obj.HasPet = obj.Name == 'Shaman' or obj.Name == 'Magician' or obj.Name == 'Necromancer' or obj.Name == 'Beastlord' or obj.Name == 'Enchanter' or obj.Name == 'Wizard' or obj.Name == 'Shadow Knight'
	obj.IsBard = obj.Name == 'Bard'

	return obj
end
