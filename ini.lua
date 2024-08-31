local mq = require('mq')
local str = require('str')


local function FilterEmpty(table)
	local filtered = {}
	for i,v in ipairs(table) do
		if string.len(v) > 0 then
			filtered[i] = v
		end
	end
	return filtered
end

local function StripComment(s)
	local parts = str.Split(s, ';')
	if #parts > 1 then
		return str.Trim(parts[1])
	else
		return s
	end
end

Section = {}
Section.__index = Section

function Section:new(filename, section_name)
	local mt = {}
	setmetatable(mt, self)

	mt.Filename = filename or ('Bot_' .. mq.TLO.Me.CleanName() .. '.ini')
	mt.Name = section_name

	return mt
end

function Section:ToTable()
	local rawkeys = mq.TLO.Ini(self.Filename, self.Name)()
	local t = {}

	if rawkeys ~= nil then
		local keys = FilterEmpty(str.Split(rawkeys, '|'))
		for i,key in ipairs(keys) do
			local value = mq.TLO.Ini(self.Filename, self.Name, key)() or ''
			t[key] = StripComment(value)
		end
	end

	return t
end

function Section:ToArray()
	local rawkeys = mq.TLO.Ini(self.Filename, self.Name)()
	local list = {}

	if rawkeys == nil then
		print('Invalid section name ' .. self.Name)
	end

	local keys = FilterEmpty(str.Split(rawkeys, '|'))

	for i,key in ipairs(keys) do
		local value = mq.TLO.Ini(self.Filename, self.Name, key)()
		table.insert(list, StripComment(value))
	end

	return list
end

function Section:IsMissing(key)
	return str.IsEmpty(mq.TLO.Ini(self.Filename, self.Name, key)())
end

function Section:LoadValueOrDefault(key, default)
	if self:IsMissing(key) then return default end
	return StripComment(mq.TLO.Ini(self.Filename, self.Name, key)())
end

function Section:String(key, default)
	return self:LoadValueOrDefault(key, default)
end

function Section:Number(key, default)
	return tonumber(self:LoadValueOrDefault(key, default))
end

function Section:Boolean(key, default)
	local v = self:LoadValueOrDefault(key, default)
	if type(v) == 'string' then
		return v == 'TRUE'
	end
	return v
end

function Section:WriteString(key, value)
	mq.cmd('/ini "' .. self.Filename .. '" "' .. self.Name .. '" "' .. key .. '" "' .. value .. '"')
end

function Section:WriteNumber(key, value)
	self:WriteString(key, value)
end

function Section:WriteBoolean(key, value)
	local s = "FALSE"
	if value then s = "TRUE" end
	self:WriteString(key, s)
end

Ini = {}
Ini.__index = Ini

function Ini:new(filename)
	local mt = {}
	setmetatable(mt, self)

	mt.Filename = filename or ('Bot_' .. mq.TLO.Me.CleanName() .. '.ini')

	return mt
end

function Ini:SectionNames()
	return FilterEmpty(str.Split(mq.TLO.Ini(self.Filename)(), '|'))
end

function Ini:HasSection(section_name)
	return mq.TLO.Ini(self.Filename, section_name)() ~= nil
end

function Ini:Section(section_name)
	return Section:new(self.Filename, section_name)
end

function Ini:SectionToTable(section_name)
	return self:Section(section_name):ToTable()
end

function Ini:SectionToArray(section_name)
	return self:Section(section_name):ToArray()
end

function Ini:IsMissing(section, key)
	return str.IsEmpty(mq.TLO.Ini(self.Filename, section, key)())
end

function Ini:String(section, key, default)
	return self:Section(section):String(key, default)
end

function Ini:Number(section, key, default)
	return self:Section(section):Number(key, default)
end

function Ini:Boolean(section, key, default)
	return self:Section(section):Boolean(key, default)
end

function Ini:WriteString(section, key, value)
	return self:Section(section):WriteString(key, value)
end

function Ini:WriteNumber(section, key, value)
	return self:Section(section):WriteNumber(key, value)
end

function Ini:WriteBoolean(section, key, value)
	return self:Section(section):WriteBoolean(key, value)
end
