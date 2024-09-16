local mq = require('mq')
local str = require('str')
local common = require('common')
local spells = require('spells')
local co = require('co')
require('ini')
require('eqclass')

MyClass = EQClass:new()


Config = {}
Config.__index = Config

function Config:new(type)
	local mt = {}
	setmetatable(mt, self)

	mt._ini = Ini:new()

	mt._type = type
	if mt._type == 'davebot' then
		mt._spells = SpellsConfig:new(mt._ini)
		mt._spellbar = SpellBarConfig:new(mt._ini, mt._spells)
		mt._autosit = AutoSitConfig:new(mt._ini)
		mt._tether = TetherConfig:new(mt._ini)
		mt._twist = TwistConfig:new(mt._ini)
		mt._teamevents = TeamEventsConfig:new(mt._ini)
	elseif mt._type == 'meleebot' then
		mt._melee = MeleeConfig:new(mt._ini)
	else
		local watch_cc = false
		if mt._type == 'debuffbot' or mt._type == 'dotbot' or mt._type == 'nukebot' or mt._type == 'songbot' then
			watch_cc = true
		end
		local watch_bc = false
		if mt._type == 'gembot' or mt._type == 'songbot' then
			watch_bc = true
		end
		mt._spells = SpellsConfig:new(mt._ini)
		mt._spellbar = SpellBarConfig:new(mt._ini, mt._spells)
	end

	if mt._type == 'castqueue' then
		mt._castqueue = CastQueueConfig:new(mt._ini)
	end
	if mt._type == 'buffbot' then
		mt._buff = BuffConfig:new(mt._ini)
	end
	if mt._type == 'crowdcontrolbot' then
		mt._cc = CrowdControlConfig:new(mt._ini)
	end
	if mt._type == 'debuffbot' then
		mt._debuff = DebuffConfig:new(mt._ini)
	end
	if mt._type == 'dotbot' then
		mt._dot = DotConfig:new(mt._ini)
	end
	if mt._type == 'healbot' then
		mt._heal = HealConfig:new(mt._ini)
	end
	if mt._type == 'nukebot' then
		mt._dd = DdConfig:new(mt._ini)
	end
	if mt._type == 'petbot' then
		mt._pet = PetConfig:new(mt._ini)
	end

	mt._last_load_time = mq.gettime()

	return mt
end

function Config:Reload(min_interval)
	if mq.gettime() >= self._last_load_time + (min_interval or 10000) then
		self._ini:Reload()

		co.yield()

		if self._type == 'davebot' then
			self._tether:Calculate()
			self._teamevents:Calculate()
			self._autosit:Calculate()
			if MyClass.HasSpells or MyClass.IsBard then
				self._spellbar:Calculate()
			end
			if MyClass.IsBard then
				self._twist:Calculate()
			end
			co.yield()
		elseif self._type == 'meleebot' then
			self._melee:Calculate()
			co.yield()
		else
			self._spellbar:Calculate()
			co.yield()
		end

		if self._type == 'castqueue' then
			self._castqueue:Calculate()
			co.yield()
		end
		if self._type == 'buffbot' then
			self._buff:Calculate()
			co.yield()
		end
		if self._type == 'crowdcontrolbot' then
			self._cc:Calculate()
			co.yield()
		end
		if self._type == 'debuffbot' then
			self._debuff:Calculate()
			co.yield()
		end
		if self._type == 'dotbot' then
			self._dot:Calculate()
			co.yield()
		end
		if self._type == 'healbot' then
			self._heal:Calculate()
			co.yield()
		end
		if self._type == 'nukebot' then
			self._dd:Calculate()
			co.yield()
		end
		if self._type == 'petbot' then
			self._pet:Calculate()
			co.yield()
		end

		self._last_load_time = mq.gettime()
	end
end

function Config:Spells()
	return self._spells
end

function Config:SpellBar()
	return self._spellbar
end

function Config:CastQueue()
	return self._castqueue
end

function Config:AutoSit()
	return self._autosit
end

function Config:Buff()
	return self._buff
end

function Config:CrowdControl()
	return self._cc
end

function Config:Debuff()
	return self._debuff
end

function Config:Dot()
	return self._dot
end

function Config:Heal()
	return self._heal
end

function Config:Melee()
	return self._melee
end

function Config:Dd()
	return self._dd
end

function Config:Pet()
	return self._pet
end

function Config:Twist()
	return self._twist
end

function Config:Tether()
	return self._tether
end

function Config:TeamEvents()
	return self._teamevents
end


SpellsConfig = {}
SpellsConfig.__index = SpellsConfig

function SpellsConfig:new(ini)
	local mt = {}
	setmetatable(mt, self)

	mt._ini = ini

	return mt
end

function SpellsConfig:Spell(spell_key)
	return self._ini:String('Spells', spell_key, '')
end


SpellBarConfig = {}
SpellBarConfig.__index = SpellBarConfig

function SpellBarConfig:new(ini, spells_config)
	local mt = {}
	setmetatable(mt, self)

	mt._defaults = {}
	mt._mode_overlays = {}
	mt._flag_overlays = {}
	mt._mode_flag_overlays = {}
	mt._ini = ini
	mt._spells_config = spells_config
	mt:Calculate()

	return mt
end

function SpellBarConfig:_split_gems(spell_bar)
	local value = {}
	local gems = str.Split(spell_bar, ',')
	for i, gem in ipairs(gems) do
		local idx = gem:find(':')
		value[tonumber(gem:sub(1, idx - 1))] = gem:sub(idx + 1, -1)
	end
	return value
end

function SpellBarConfig:_defaults_from_ini()
	local defaults = self:_split_gems(self._ini:String('Default', 'SpellBar', ''))
	for i=1,mq.TLO.Me.NumGems() do
		if not defaults[i] then defaults[i] = 'OPEN' end
	end
	return defaults
end

function SpellBarConfig:_flag_overlays_from_ini()
	local overlays = {}
	for i, name in ipairs(self._ini:SectionNames()) do
		if str.StartsWith(name, 'Flag:') then
			local parts = str.Split(name, ':')
			if #parts == 2 and not tonumber(parts[2]) then
				overlays[parts[2]] = self:_split_gems(self._ini:String(name, 'SpellBar', ''))
			end
		end
	end
	return overlays
end

function SpellBarConfig:_mode_flag_overlays_from_ini(mode)
	local overlays = {}
	for i, section_name in ipairs(self._ini:SectionNames()) do
		if str.StartsWith(section_name, 'Flag:' .. mode .. ':') then
			local parts = str.Split(section_name, ':')
			if #parts == 3 then
				overlays[parts[3]] = self:_split_gems(self._ini:String(section_name, 'SpellBar', ''))
			end
		end
	end
	return overlays
end

function SpellBarConfig:_mode_overlays_from_ini(mode)
	return self:_split_gems(self._ini:String('Mode:' .. mode, 'SpellBar', ''))
end

function SpellBarConfig:Calculate()
	local start = mq.gettime()
	self._defaults = self:_defaults_from_ini()
	self._flag_overlays = self:_flag_overlays_from_ini()
	for i=2,4 do
		self._mode_overlays[i] = self:_mode_overlays_from_ini(i)
		self._mode_flag_overlays[i] = self:_mode_flag_overlays_from_ini(i)
	end
	self._last_load_time = mq.gettime()
end

function SpellBarConfig:Gems()
	local mode = mq.TLO.DaveBot.Mode.Mode()
	local flags = {}
	for i=1,mq.TLO.DaveBot.Mode.FlagCount() do
		table.insert(flags, mq.TLO.DaveBot.Mode.Flag(i))
	end

	local overlaid = {}
	for k,v in pairs(self._defaults) do
		overlaid[k] = v
	end
	for k,v in pairs(self._mode_overlays[mode] or {}) do
		overlaid[k] = v
	end
	for i, flag in ipairs(flags) do
		local flag_overlay = self._flag_overlays[flag] or {}
		for k,v in pairs(flag_overlay) do
			overlaid[k] = v
		end
		if mode == nil then
			print('config.lua 311: mode is nil')
		end
		local mode_flag_overlay = self._mode_flag_overlays[mode][flag] or {}
		for k,v in pairs(mode_flag_overlay) do
			overlaid[k] = v
		end
	end
	return overlaid
end

function SpellBarConfig:GemAndSpellByKey(spell_key)
	if spell_key == '' then
		return -3, '', 'Spell not defined'
	else
		local ref = self._spells_config:Spell(spell_key)
		if ref == '' then
			return -2, '', 'Cannot find spell key: ' .. spell_key
		else
			local spell_name = spells.ReferenceSpell(ref)
			if spell_name == '' then
				return -1, '', 'Cannot find spell for reference: ' .. ref
			else
				local gem = self:GemBySpellKey(spell_key)
				if gem == 0 then gem = self:FirstOpenGem() end
				if gem == 0 then
					return 0, spell_name, 'Cannot find gem for key: ' .. spell_key
				else
					return gem, spell_name, ''
				end
			end
		end
	end
end

function SpellBarConfig:SpellKeyByGem(gem)
	local spell_bar = self:Gems()
	return spell_bar[gem]
end

function SpellBarConfig:GemBySpellKey(spell)
	local spell_bar = self:Gems()
	for k,v in pairs(spell_bar) do
		if spell == v then return k end
	end
	return 0
end

function SpellBarConfig:FirstOpenGem()
	local spell_bar = self:Gems()
	for k,v in pairs(spell_bar) do
		if 'OPEN' == v then return k end
	end
	return 0
end




local function mode_flag_overlays_from_ini(ini, type, mode)
	local overlays = {}
	for i, section_name in ipairs(ini:SectionNames()) do
		if str.StartsWith(section_name, 'Flag:' .. mode .. ':') and str.EndsWith(section_name, ':' .. type) then
			local parts = str.Split(section_name, ':')
			if #parts == 4 then
				overlays[parts[3]] = ini:Section(section_name)
			end
		end
	end
	return overlays
end

local function flag_overlays_from_ini(ini, type)
	local overlays = {}
	for i, section_name in ipairs(ini:SectionNames()) do
		if str.StartsWith(section_name, 'Flag:') and str.EndsWith(section_name, ':' .. type) then
			local parts = str.Split(section_name, ':')
			if #parts == 3 and not tonumber(parts[2]) then
				overlays[parts[3]] = ini:Section(section_name)
			end
		end
	end
	return overlays
end

local function mode_overlays_from_ini(ini, type, mode)
	return ini:Section('Mode:' .. mode .. ':' .. type):ToTable() or {}
end

local function defaults_from_ini(ini, type)
	return ini:Section('Default:' .. type):ToTable() or {}
end

local function mode_value(defaults, mode_overlays, flag_overlays, mode_flag_overlays, key, default)
	local mode = mq.TLO.DaveBot.Mode.Mode()
	local flags = {}
	for i=1,mq.TLO.DaveBot.Mode.FlagCount() do
		table.insert(flags, mq.TLO.DaveBot.Mode.Flag(i))
	end

	local value = defaults[key]
	if mode_overlays[mode] then
		if mode_overlays[mode][key] then
			value = mode_overlays[mode][key]
		end
	end
	for i, flag in ipairs(flags) do
		if flag_overlays[flag] and flag_overlays[flag][key] then
			value = flag_overlays[flag][key]
		end
	end
	if mode_flag_overlays[mode] then
		for i, flag in ipairs(flags) do
			if mode_flag_overlays[mode][flag] and mode_flag_overlays[mode][flag][key] then
				value = mode_flag_overlays[mode][flag][key]
			end
		end
	end

	return value or default
end


--
-- Cast Queue
--

CastQueueConfig = {}
CastQueueConfig.__index = CastQueueConfig

function CastQueueConfig:new(ini)
	local mt = {}
	setmetatable(mt, self)

	mt._defaults = {}
	mt._mode_overlays = {}
	mt._flag_overlays = {}
	mt._mode_flag_overlays = {}

	mt._ini = ini
	mt:Calculate()

	return mt
end

function CastQueueConfig:Calculate()
	local type = 'CastQueue'
	self._defaults = defaults_from_ini(self._ini, type)
	self._flag_overlays = flag_overlays_from_ini(self._ini, type)
	for i=2,4 do
		self._mode_overlays[i] = mode_overlays_from_ini(self._ini, type, i)
		self._mode_flag_overlays[i] = mode_flag_overlays_from_ini(self._ini, type, i)
	end
	self._last_load_time = mq.gettime()
end

function CastQueueConfig:_mode_value(key, default)
	return mode_value(self._defaults, self._mode_overlays, self._flag_overlays, self._mode_flag_overlays, key, default)
end

function CastQueueConfig:Print()
	return self:_mode_value('Print', 'FALSE')
end

function CastQueueConfig:PrintTimer()
	return tonumber(self:_mode_value('PrintTimer', '10'))
end


--
-- Autosit
--

AutoSitConfig = {}
AutoSitConfig.__index = AutoSitConfig

function AutoSitConfig:new(ini)
	local mt = {}
	setmetatable(mt, self)

	mt._defaults = {}
	mt._mode_overlays = {}
	mt._flag_overlays = {}
	mt._mode_flag_overlays = {}

	mt._ini = ini
	mt:Calculate()

	return mt
end

function AutoSitConfig:Calculate()
	local type = 'AutoSit'
	self._defaults = defaults_from_ini(self._ini, type)
	self._flag_overlays = flag_overlays_from_ini(self._ini, type)
	for i=2,4 do
		self._mode_overlays[i] = mode_overlays_from_ini(self._ini, type, i)
		self._mode_flag_overlays[i] = mode_flag_overlays_from_ini(self._ini, type, i)
	end
	self._last_load_time = mq.gettime()
end

function AutoSitConfig:_mode_value(key, default)
	return mode_value(self._defaults, self._mode_overlays, self._flag_overlays, self._mode_flag_overlays, key, default)
end

function AutoSitConfig:Enabled()
	return self:_mode_value('Enabled', false)
end

function AutoSitConfig:MinHPs()
	return self:_mode_value('MinHPs', 95)
end

function AutoSitConfig:MinMana()
	return self:_mode_value('MinMana', 95)
end

function AutoSitConfig:OverrideOnMove()
	return self:_mode_value('OverrideOnMove', false)
end

function AutoSitConfig:OverrideSeconds()
	return self:_mode_value('OverrideSeconds', 10)
end


--
-- Buff
--

BuffConfig = {}
BuffConfig.__index = BuffConfig

function BuffConfig:new(ini)
	local mt = {}
	setmetatable(mt, self)

	mt._defaults = {}
	mt._mode_overlays = {}
	mt._flag_overlays = {}
	mt._mode_flag_overlays = {}

	mt._ini = ini
	mt:Calculate()

	return mt
end

function BuffConfig:Calculate()
	local type = 'Buff'
	self._defaults = defaults_from_ini(self._ini, type)
	self._flag_overlays = flag_overlays_from_ini(self._ini, type)
	for i=2,4 do
		self._mode_overlays[i] = mode_overlays_from_ini(self._ini, type, i)
		self._mode_flag_overlays[i] = mode_flag_overlays_from_ini(self._ini, type, i)
	end
	self._last_load_time = mq.gettime()
end

function BuffConfig:_mode_value(key, default)
	return mode_value(self._defaults, self._mode_overlays, self._flag_overlays, self._mode_flag_overlays, key, default)
end

function BuffConfig:Enabled()
	return self:_mode_value('Enabled', false)
end

function BuffConfig:MinMana()
	return self:_mode_value('MinMana', 45)
end

function BuffConfig:Backoff()
	return self:_mode_value('Backoff', true)
end

function BuffConfig:BackoffTimer()
	return self:_mode_value('BackoffTimer', 300) * 1000
end

function BuffConfig:PackageByName(name)
	return str.Split(self:_mode_value(name, ''), ',')
end

-- function BuffConfig:TankPackage()
-- 	return str.Split(self:_mode_value('Tank', ''), ',')
-- end

-- function BuffConfig:MeleePackage()
-- 	return str.Split(self:_mode_value('Melee', ''), ',')
-- end

-- function BuffConfig:CasterPackage()
-- 	return str.Split(self:_mode_value('Caster', ''), ',')
-- end

-- function BuffConfig:PetPackage()
-- 	return str.Split(self:_mode_value('Pet', ''), ',')
-- end

-- function BuffConfig:SelfPackage()
-- 	return str.Split(self:_mode_value('Self', ''), ',')
-- end

-- function BuffConfig:SelfpetPackage()
-- 	return str.Split(self:_mode_value('Selfpet', ''), ',')
-- end



CrowdControlConfig = {}
CrowdControlConfig.__index = CrowdControlConfig

function CrowdControlConfig:new(ini)
	local mt = {}
	setmetatable(mt, self)

	mt._defaults = {}
	mt._mode_overlays = {}
	mt._flag_overlays = {}
	mt._mode_flag_overlays = {}

	mt._ini = ini
	mt:Calculate()

	return mt
end

function CrowdControlConfig:Calculate()
	local type = 'CrowdControl'
	self._defaults = defaults_from_ini(self._ini, type)
	self._flag_overlays = flag_overlays_from_ini(self._ini, type)
	for i=2,4 do
		self._mode_overlays[i] = mode_overlays_from_ini(self._ini, type, i)
		self._mode_flag_overlays[i] = mode_flag_overlays_from_ini(self._ini, type, i)
	end
	self._last_load_time = mq.gettime()
end

function CrowdControlConfig:_mode_value(key, default)
	return mode_value(self._defaults, self._mode_overlays, self._flag_overlays, self._mode_flag_overlays, key, default)
end

function CrowdControlConfig:Enabled()
	return self:_mode_value('Enabled', false)
end

function CrowdControlConfig:MinMana()
	return self:_mode_value('MinMana', 10)
end

function CrowdControlConfig:IAmPrimary()
	return self:_mode_value('IAmPrimary', false)
end

function CrowdControlConfig:Spell()
	return self:_mode_value('Spell', '')
end


DebuffConfig = {}
DebuffConfig.__index = DebuffConfig

function DebuffConfig:new(ini)
	local mt = {}
	setmetatable(mt, self)

	mt._defaults = {}
	mt._mode_overlays = {}
	mt._flag_overlays = {}
	mt._mode_flag_overlays = {}

	mt._ini = ini
	mt:Calculate()

	return mt
end

function DebuffConfig:Calculate()
	local type = 'Debuff'
	self._defaults = defaults_from_ini(self._ini, type)
	self._flag_overlays = flag_overlays_from_ini(self._ini, type)
	for i=2,4 do
		self._mode_overlays[i] = mode_overlays_from_ini(self._ini, type, i)
		self._mode_flag_overlays[i] = mode_flag_overlays_from_ini(self._ini, type, i)
	end
	self._last_load_time = mq.gettime()
end

function DebuffConfig:_mode_value(key, default)
	return mode_value(self._defaults, self._mode_overlays, self._flag_overlays, self._mode_flag_overlays, key, default)
end

function DebuffConfig:Enabled()
	return self:_mode_value('Enabled', false)
end

function DebuffConfig:MinMana()
	return self:_mode_value('MinMana', 45)
end

function DebuffConfig:MinTargetHpPct()
	return self:_mode_value('MinTargetHpPct', 65)
end

function DebuffConfig:AtTargetHpPcts()
	local csv = str.Split(self:_mode_value('Pcts', ''), ',')
	local pcts = {}
	for i,s in ipairs(csv) do
		local parts = str.Split(s, ':')
		pcts[tonumber(parts[2])] = parts[1]
	end
	return pcts
end


DotConfig = {}
DotConfig.__index = DotConfig

function DotConfig:new(ini)
	local mt = {}
	setmetatable(mt, self)

	mt._defaults = {}
	mt._mode_overlays = {}
	mt._flag_overlays = {}
	mt._mode_flag_overlays = {}

	mt._ini = ini
	mt:Calculate()

	return mt
end

function DotConfig:Calculate()
	local type = 'Dot'
	self._defaults = defaults_from_ini(self._ini, type)
	self._flag_overlays = flag_overlays_from_ini(self._ini, type)
	for i=2,4 do
		self._mode_overlays[i] = mode_overlays_from_ini(self._ini, type, i)
		self._mode_flag_overlays[i] = mode_flag_overlays_from_ini(self._ini, type, i)
	end
	self._last_load_time = mq.gettime()
end

function DotConfig:_mode_value(key, default)
	return mode_value(self._defaults, self._mode_overlays, self._flag_overlays, self._mode_flag_overlays, key, default)
end

function DotConfig:Enabled()
	return self:_mode_value('Enabled', false)
end

function DotConfig:MinMana()
	return self:_mode_value('MinMana', 50)
end

function DotConfig:MinTargetHpPct()
	return self:_mode_value('MinTargetHpPct', 65)
end

function DotConfig:AtTargetHpPcts()
	local csv = str.Split(self:_mode_value('Pcts', ''), ',')
	local pcts = {}
	for i,s in ipairs(csv) do
		local parts = str.Split(s, ':')
		pcts[tonumber(parts[2])] = parts[1]
	end
	return pcts
end


HealConfig = {}
HealConfig.__index = HealConfig

function HealConfig:new(ini)
	local mt = {}
	setmetatable(mt, self)

	mt._defaults = {}
	mt._mode_overlays = {}
	mt._flag_overlays = {}
	mt._mode_flag_overlays = {}

	mt._ini = ini
	mt:Calculate()

	return mt
end

function HealConfig:Calculate()
	local type = 'Heal'
	self._defaults = defaults_from_ini(self._ini, type)
	self._flag_overlays = flag_overlays_from_ini(self._ini, type)
	for i=2,4 do
		self._mode_overlays[i] = mode_overlays_from_ini(self._ini, type, i)
		self._mode_flag_overlays[i] = mode_flag_overlays_from_ini(self._ini, type, i)
	end
	self._last_load_time = mq.gettime()
end

function HealConfig:_mode_value(key, default)
	return mode_value(self._defaults, self._mode_overlays, self._flag_overlays, self._mode_flag_overlays, key, default)
end

function HealConfig:Enabled()
	return self:_mode_value('Enabled', false)
end

function HealConfig:MinMana()
	return self:_mode_value('MinMana', 0)
end

function HealConfig:AtHpPct(type)
	local parts = str.Split(self:_mode_value(type, ''), ':')
	if #parts == 2 then
		return tonumber(parts[2]), parts[1]
	else
		return 0, ''
	end
end

function HealConfig:GroupAtHpPct()
	return self:AtHpPct('Group')
end

function HealConfig:TankAtHpPct()
	return self:AtHpPct('Tank')
end

function HealConfig:MeleeAtHpPct()
	return self:AtHpPct('Melee')
end

function HealConfig:CasterAtHpPct()
	return self:AtHpPct('Caster')
end

function HealConfig:PetAtHpPct()
	return self:AtHpPct('Pet')
end

function HealConfig:SelfAtHpPct()
	return self:AtHpPct('Self')
end

function HealConfig:SelfpetAtHpPct()
	return self:AtHpPct('Selfpet')
end


--
-- Melee
--

MeleeConfig = {}
MeleeConfig.__index = MeleeConfig

function MeleeConfig:new(ini)
	local mt = {}
	setmetatable(mt, self)

	mt._defaults = {}
	mt._mode_overlays = {}
	mt._flag_overlays = {}
	mt._mode_flag_overlays = {}

	mt._ini = ini
	mt:Calculate()

	return mt
end

function MeleeConfig:Calculate()
	local type = 'Melee'
	self._defaults = defaults_from_ini(self._ini, type)
	self._flag_overlays = flag_overlays_from_ini(self._ini, type)
	for i=2,4 do
		self._mode_overlays[i] = mode_overlays_from_ini(self._ini, type, i)
		self._mode_flag_overlays[i] = mode_flag_overlays_from_ini(self._ini, type, i)
	end
	self._last_load_time = mq.gettime()
end

function MeleeConfig:_mode_value(key, default)
	return mode_value(self._defaults, self._mode_overlays, self._flag_overlays, self._mode_flag_overlays, key, default)
end

function MeleeConfig:Enabled()
	return self:_mode_value('Enabled', false)
end

function MeleeConfig:EngageTargetHPs()
	return self:_mode_value('EngageTargetHPs', 95)
end

function MeleeConfig:EngageTargetDistance()
	return self:_mode_value('EngageTargetDistance', 75)
end


--
-- DD
--

DdConfig = {}
DdConfig.__index = DdConfig

function DdConfig:new(ini)
	local mt = {}
	setmetatable(mt, self)

	mt._defaults = {}
	mt._mode_overlays = {}
	mt._flag_overlays = {}
	mt._mode_flag_overlays = {}

	mt._ini = ini
	mt:Calculate()

	return mt
end

function DdConfig:Calculate()
	local type = 'DD'
	self._defaults = defaults_from_ini(self._ini, type)
	self._flag_overlays = flag_overlays_from_ini(self._ini, type)
	for i=2,4 do
		self._mode_overlays[i] = mode_overlays_from_ini(self._ini, type, i)
		self._mode_flag_overlays[i] = mode_flag_overlays_from_ini(self._ini, type, i)
	end
	self._last_load_time = mq.gettime()
end

function DdConfig:_mode_value(key, default)
	return mode_value(self._defaults, self._mode_overlays, self._flag_overlays, self._mode_flag_overlays, key, default)
end

function DdConfig:Enabled()
	return self:_mode_value('Enabled', false)
end

function DdConfig:MinMana()
	return self:_mode_value('MinMana', 50)
end

function DdConfig:MinTargetHpPct()
	return self:_mode_value('MinTargetHpPct', 0)
end

function DdConfig:AtTargetHpPcts()
	local csv = str.Split(self:_mode_value('Pcts', ''), ',')
	local pcts = {}
	for i,s in ipairs(csv) do
		local parts = str.Split(s, ':')
		pcts[tonumber(parts[2])] = parts[1]
	end
	return pcts
end


--
-- Pet
--

PetConfig = {}
PetConfig.__index = PetConfig

local function default_pet_type()
	local type = ''
	if MyClass.Name == 'Magician' then
		type = 'Water'
	elseif MyClass.Name == 'Shaman' then
		type = 'Warder'
	elseif MyClass.Name == 'Shadow Knight' then
		type = 'Undead'
	elseif MyClass.Name == 'Necromancer' then
		type = 'Undead'
	elseif MyClass.Name == 'Beastlord' then
		print('Need Beastlord Code')
	elseif MyClass.Name == 'Enchanter' then
		type = 'Animation'
	elseif MyClass.Name == 'Wizard' then
		type = 'Familiar'
	end
	return type
end

function PetConfig:new(ini)
	local mt = {}
	setmetatable(mt, self)

	mt.DefaultPetType = default_pet_type()

	mt._defaults = {}
	mt._mode_overlays = {}
	mt._flag_overlays = {}
	mt._mode_flag_overlays = {}

	mt._ini = ini
	mt:Calculate()

	return mt
end

function PetConfig:Calculate()
	local type = 'Pet'
	self._defaults = defaults_from_ini(self._ini, type)
	self._flag_overlays = flag_overlays_from_ini(self._ini, type)
	for i=2,4 do
		self._mode_overlays[i] = mode_overlays_from_ini(self._ini, type, i)
		self._mode_flag_overlays[i] = mode_flag_overlays_from_ini(self._ini, type, i)
	end
	self._last_load_time = mq.gettime()
end

function PetConfig:_mode_value(key, default)
	return mode_value(self._defaults, self._mode_overlays, self._flag_overlays, self._mode_flag_overlays, key, default)
end

function PetConfig:AutoCast()
	return self:_mode_value('AutoCast', false)
end

function PetConfig:AutoAttack()
	return self:_mode_value('AutoAttack', false)
end

function PetConfig:Type()
	return self:_mode_value('Type', self.DefaultPetType)
end

function PetConfig:MinMana()
	return self:_mode_value('MinMana', 50)
end

function PetConfig:EngageTargetHPs()
	return self:_mode_value('EngageTargetHPs', 95)
end

function PetConfig:EngageTargetDistance()
	return self:_mode_value('EngageTargetDistance', 75)
end


--
-- Twist
--

TwistConfig = {}
TwistConfig.__index = TwistConfig

function TwistConfig:new(ini)
	local mt = {}
	setmetatable(mt, self)

	mt._defaults = {}
	mt._mode_overlays = {}
	mt._flag_overlays = {}
	mt._mode_flag_overlays = {}

	mt._ini = ini
	mt:Calculate()

	return mt
end

function TwistConfig:Calculate()
	local type = 'Twist'
	self._defaults = defaults_from_ini(self._ini, type)
	self._flag_overlays = flag_overlays_from_ini(self._ini, type)
	for i=2,4 do
		self._mode_overlays[i] = mode_overlays_from_ini(self._ini, type, i)
		self._mode_flag_overlays[i] = mode_flag_overlays_from_ini(self._ini, type, i)
	end
	self._last_load_time = mq.gettime()
end

function TwistConfig:_mode_value(key, default)
	return mode_value(self._defaults, self._mode_overlays, self._flag_overlays, self._mode_flag_overlays, key, default)
end

function TwistConfig:Enabled()
	return self:_mode_value('Enabled', false)
end

function TwistConfig:Order()
	return str.Split(self:_mode_value('Order', ''), ',')
end

function TwistConfig:CombatOrder()
	return str.Split(self:_mode_value('CombatOrder', ''), ',')
end


--
-- Tether
--

TetherConfig = {}
TetherConfig.__index = TetherConfig

function TetherConfig:new(ini)
	local mt = {}
	setmetatable(mt, self)

	mt._defaults = {}
	mt._mode_overlays = {}
	mt._flag_overlays = {}
	mt._mode_flag_overlays = {}

	mt._ini = ini
	mt:Calculate()

	return mt
end

function TetherConfig:Calculate()
	local type = 'Tether'
	self._defaults = defaults_from_ini(self._ini, type)
	self._flag_overlays = flag_overlays_from_ini(self._ini, type)
	for i=2,4 do
		self._mode_overlays[i] = mode_overlays_from_ini(self._ini, type, i)
		self._mode_flag_overlays[i] = mode_flag_overlays_from_ini(self._ini, type, i)
	end
	self._last_load_time = mq.gettime()
end

function TetherConfig:_mode_value(key, default)
	return mode_value(self._defaults, self._mode_overlays, self._flag_overlays, self._mode_flag_overlays, key, default)
end

function TetherConfig:Mode()
	return self:_mode_value('Mode', 'ACTIVE')
end

function TetherConfig:ModeIsActive()
	return self:Mode():lower() == 'active'
end

function TetherConfig:ModeIsPassive()
	return self:Mode():lower() == 'passive'
end

function TetherConfig:CampMaxDistance()
	return self:_mode_value('CampMaxDistance', 40)
end

function TetherConfig:FollowMaxDistance()
	return self:_mode_value('FollowMaxDistance', 15)
end

function TetherConfig:ReturnTimer()
	return self:_mode_value('ReturnTimer', 5)
end


--
-- TeamEvents
--

TeamEventsConfig = {}
TeamEventsConfig.__index = TeamEventsConfig

function TeamEventsConfig:new(ini)
	local mt = {}
	setmetatable(mt, self)

	mt._defaults = {}
	mt._mode_overlays = {}
	mt._flag_overlays = {}
	mt._mode_flag_overlays = {}

	mt._ini = ini
	mt:Calculate()

	return mt
end

function TeamEventsConfig:Calculate()
	local type = 'TeamEvents'
	self._defaults = defaults_from_ini(self._ini, type)
	self._flag_overlays = flag_overlays_from_ini(self._ini, type)
	for i=2,4 do
		self._mode_overlays[i] = mode_overlays_from_ini(self._ini, type, i)
		self._mode_flag_overlays[i] = mode_flag_overlays_from_ini(self._ini, type, i)
	end
	self._last_load_time = mq.gettime()
end

function TeamEventsConfig:_mode_value(key, default)
	return mode_value(self._defaults, self._mode_overlays, self._flag_overlays, self._mode_flag_overlays, key, default)
end

function TeamEventsConfig:OnPullStart()
	return self:_mode_value('OnPullStart', '')
end

function TeamEventsConfig:OnPullEnd()
	return self:_mode_value('OnPullEnd', '')
end

function TeamEventsConfig:OnPreEngage()
	return self:_mode_value('OnPreEngage', '')
end

function TeamEventsConfig:OnEngage()
	return self:_mode_value('OnEngage', '')
end