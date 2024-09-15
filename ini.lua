local mq = require('mq')
local str = require('str')
local lip = require('LIP')
local common = require('common')


local function FilterEmpty(table)
	local filtered = {}
	for i,v in ipairs(table) do
		if string.len(v) > 0 then
			filtered[i] = v
		else
			print('Found empty')
		end
	end
	return filtered
end

-- local function StripComment(s)
-- 	local parts = str.Split(s, ';')
-- 	if #parts > 1 then
-- 		return str.Trim(parts[1])
-- 	else
-- 		return s
-- 	end
-- end

Section = {}
Section.__index = Section

function Section:new(filename, data, section_name)
	local mt = {}
	setmetatable(mt, self)

	mt._filename = filename or ('Bot_' .. mq.TLO.Me.CleanName() .. '.ini')
	mt._data = data or {}
	mt._name = section_name

	return mt
end

function Section:ToTable()
	return self._data
	-- local section = {}
	-- for k, v in pairs(self._data) do
	-- 	section[k] = StripComment(v)
	-- end
	-- return section
end

function Section:Keys()
	return FilterEmpty(common.TableKeys(self._data))
end

function Section:IsMissing(key)
	return not common.MapHasKey(self._data, key)
end

function Section:ValueOrDefault(key, default)
	if not common.MapHasKey(self._data, key) then return default end
	return self._data[key]
	-- return StripComment(self._data[key])
end

function Section:String(key, default)
	return self:ValueOrDefault(key, default)
end

function Section:Number(key, default)
	return tonumber(self:ValueOrDefault(key, default))
end

function Section:Boolean(key, default)
	local v = self:ValueOrDefault(key, default)
	if type(v) == 'string' then
		return v:lower() == 'true'
	end
	return v
end

function Section:WriteString(key, value)
	self._data[key] = value
	mq.cmd('/ini "' .. self._filename .. '" "' .. self._name .. '" "' .. key .. '" "' .. value .. '"')
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

	mt._filename = filename or ('Bot_' .. mq.TLO.Me.CleanName() .. '.ini')
	mt._path = mq.TLO.Lua.Dir() .. '\\config\\' .. mt._filename

	mt:Reload()

	return mt
end

function Ini:Reload()
	self._data = lip.load(self._path)
end

function Ini:SectionNames()
	return FilterEmpty(common.TableKeys(self._data))
end

function Ini:HasSection(section_name)
	return common.MapHasKey(self._data, section_name)
end

function Ini:Section(section_name)
	return Section:new(self._path, self._data[section_name], section_name)
end

function Ini:SectionToTable(section_name)
	return self:Section(section_name):ToTable()
end

function Ini:SectionToArray(section_name)
	return self:Section(section_name):ToArray()
end

function Ini:IsMissing(section, key)
	return str.IsEmpty(mq.TLO.Ini(self._filename, section, key)())
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
