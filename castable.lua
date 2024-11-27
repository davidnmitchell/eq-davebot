local mq = require('mq')
local str = require('str')
local spells = require('spells')


function Castable(type, name, effect)
	local self = {}
	self.__type__ = 'Castable'

	self.Type = type or ''
	self.Name = name or ''
	self.Effect = effect or ''

	self.IsCastable = true
	self.Equals = function(o)
		return o.IsCastable ~= nil and o.IsCastable and o.Type == self.Type and o.Name == self.Name and o.Effect == self.Effect
	end

	self.AsString = function()
		return 'Castable:' .. self.Type .. ':' .. self.Name .. ':' .. self.Effect
	end

	return self
end

function Spell(name, effect)
	local self = Castable('spell', name, effect)
	self.__type__ = 'Spell'

	return self
end

function Item(name, effect)
	local self = Castable('item', name, effect)
	self.__type__ = 'Item'

	return self
end

function AltAbility(name, effect)
	local self = Castable('alt', name, effect)
	self.__type__ = 'AltAbility'

	return self
end

function CastableFromRef(value)
	if value:find(',') ~= nil then
		local parts = str.Split(value, ',')

		if parts[1]:lower() == 'item' then
			local name = parts[2]
			local effect = parts[2]
			if #parts > 2 then effect = parts[3] end

			return Item(name, effect)
		elseif parts[1]:lower() == 'alt' then
			local name = parts[2]
			local effect = parts[2]
			if #parts > 2 then effect = parts[3] end

			return AltAbility(name, effect)
		else
			local name = ''
			if #parts == 3 then
				name = spells.FindSpell(parts[1], parts[2], parts[3])
			else
				name = spells.FindSpell(parts[1], parts[2], parts[3], parts[4])
			end
			if #name == 0 then
				local self = Spell(name, name)
				self.__type__ = 'FailedLookedUpSpell'
				self.Error = 'Cannot find spell for reference: ' .. value

				return self
			else
				local self = Spell(name, name)
				self.__type__ = 'LookedUpSpell'

				return self
			end
		end
	else
		local v = value or ''
		return Spell(v, v)
	end
end

function CastableFromKey(key, value)
	local self = CastableFromRef(value)
	self.Key = key
	return self
end
