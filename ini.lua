local mq = require('mq')
local str = require('str')
local lip = require('LIP')
local array = require('array')
local common = require('common')


local function FilterEmpty(table)
	return array.Filtered(table, function(v) return string.len(v) > 0 end)
end

function Section(filename, data, name)
	local self = {}
	self.__type__ = 'Section'

	filename = filename or ('Bot_' .. mq.TLO.Me.CleanName() .. '.ini')
	data = data or {}

	self.ToTable = function() return data end
	self.Keys = function() return FilterEmpty(common.TableKeys(data)) end
	self.IsMissing = function(key) return not common.MapHasKey(data, key) end

	local function ValueOrDefault(key, default)
		if not common.MapHasKey(data, key) then return default end
		return data[key]
	end

	self.String = function(key, default)
		return ValueOrDefault(key, default)
	end

	self.Number = function(key, default)
		return tonumber(ValueOrDefault(key, default))
	end

	self.Boolean = function(key, default)
		local v = ValueOrDefault(key, default)
		if type(v) == 'string' then
			return v:lower() == 'true'
		end
		return v
	end

	self.WriteString = function(key, value)
		data[key] = str.Trim(lip.StripComment(value))
		mq.cmd('/ini "' .. filename .. '" "' .. name .. '" "' .. key .. '" "' .. value .. '"')
	end

	self.WriteNumber = function(key, value)
		self.WriteString(key, tostring(value))
	end

	self.WriteBoolean = function(key, value)
		local s = "FALSE"
		if value then s = "TRUE" end
		self.WriteString(key, s)
	end

	return self
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

function Ini:_copy_sample()
	local file = assert(io.open(mq.TLO.Lua.Dir() .. '\\config\\Sample.ini', 'r'))
	local content = file:read('*a')
	file:close()

	file = assert(io.open(self._path, 'w'))
	file:write(content)
	file:close()
end

function Ini:Reload()
	local file, err = io.open(self._path, 'r')
	if err then
		self:_copy_sample()
	else
		file:close()
	end
	self._data = lip.load(self._path)
end

function Ini:SectionNames()
	return FilterEmpty(common.TableKeys(self._data))
end

function Ini:HasSection(section_name)
	return common.MapHasKey(self._data, section_name)
end

function Ini:Section(section_name)
	return Section(self._path, self._data[section_name], section_name)
end

function Ini:SectionToTable(section_name)
	return self:Section(section_name).ToTable()
end

function Ini:SectionToArray(section_name)
	return self:Section(section_name).ToArray()
end

function Ini:IsMissing(section, key)
	return str.IsEmpty(mq.TLO.Ini(self._filename, section, key)())
end

function Ini:String(section, key, default)
	return self:Section(section).String(key, default)
end

function Ini:Number(section, key, default)
	return self:Section(section).Number(key, default)
end

function Ini:Boolean(section, key, default)
	return self:Section(section).Boolean(key, default)
end

function Ini:WriteString(section, key, value)
	return self:Section(section).WriteString(key, value)
end

function Ini:WriteNumber(section, key, value)
	return self:Section(section).WriteNumber(key, value)
end

function Ini:WriteBoolean(section, key, value)
	return self:Section(section).WriteBoolean(key, value)
end
