local mq = require('mq')
local str = require('str')
local spells = require('spells')


Spell = {}
Spell.__index = Spell

function Spell:new(spell_key, spell_ref)
	local obj = {}
	setmetatable(obj, Spell)

	obj.Key = spell_key
	if spell_ref == nil or spell_ref:len() == 0 then
		obj.Error = 'Cannot find spell key: ' .. spell_key
	else
		if spell_ref:find(',') ~= nil then
			local parts = str.Split(spell_ref, ',')

			if parts[1]:lower() == 'item' then
				obj.Type = 'item'
				obj.Name = parts[2]
				obj.Effect = parts[2]
				if #parts > 2 then obj.Effect = parts[3] end
			elseif parts[1]:lower() == 'alt' then
				obj.Type = 'alt'
				obj.Name = parts[2]
				obj.Effect = parts[2]
				if #parts > 2 then obj.Effect = parts[3] end
			else
				obj.Type = 'spell'
				if #parts == 3 then
					obj.Name = spells.FindSpell(parts[1], parts[2], parts[3])
				else
					obj.Name = spells.FindSpell(parts[1], parts[2], parts[3], parts[4])
				end
				if obj.Name:len() == 0 then
					obj.Error = 'Cannot find spell for reference: ' .. spell_ref
				end
				obj.Effect = obj.Name
				obj.Lookup = 'lookup'
			end
		else
			obj.Type = 'spell'
			obj.Name = spell_ref or ''
			obj.Effect = obj.Name
			obj.Lookup = 'direct'
		end
	end
	return obj
end
