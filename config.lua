local mq = require('mq')
local str = require('str')
local common = require('common')
local spells = require('spells')
require('ini')
require('eqclass')

MyClass = EQClass:new()


SpellsConfig = {}
SpellsConfig.__index = SpellsConfig

function SpellsConfig:new()
	local mt = {}
	setmetatable(mt, self)

	mt._spells = {}
	mt.Ini = Ini:new()
	mt:Load()

	return mt
end

function SpellsConfig:Load()
	self._spells = self.Ini:SectionToTable('Spells')
	self._last_load_time = mq.gettime()
end

function SpellsConfig:Reload(min_interval)
	if mq.gettime() >= self._last_load_time + (min_interval or 20000) then
		self:Load()
	end
end

function SpellsConfig:Spell(spell_key)
	return self._spells[spell_key] or ''
end


SpellBarConfig = {}
SpellBarConfig.__index = SpellBarConfig

function SpellBarConfig:new()
	local mt = {}
	setmetatable(mt, self)

	mt.Defaults = {}
	mt.Modes = {}
	--mt.Overlays = {} TODO: Default level overlays
	mt.ModeOverlays = {}
	mt.Ini = Ini:new()
	mt:Load()

	return mt
end

function SpellBarConfig:_load_defaults(section_names)
	local defaults = {}
	if common.TableHasValue(section_names, 'Default') then
		local raw_string = self.Ini:Section('Default'):String('SpellBar')
		local gems = str.Split(raw_string, ',')
		for j=1,#gems do
			local gem = str.Split(gems[j], ':')
			defaults[tonumber(gem[1])] = gem[2]
		end
		for j=1,mq.TLO.Me.NumGems() do
			if not defaults[j] then defaults[j] = 'OPEN' end
		end
	end
	return defaults
end

function SpellBarConfig:_load_overlay(mode, flag)
	local raw_string = self.Ini:Section('Flag:' .. mode .. ':' .. flag):String('SpellBar')
	local gems = str.Split(raw_string, ',')
	local overlay = {}
	for j=1,#gems do
		local gem = str.Split(gems[j], ':')
		overlay[tonumber(gem[1])] = gem[2]
	end
	return overlay
end

function SpellBarConfig:_load_overlays_by_mode(mode, section_names)
	local overlays = {}
	for i=1,#section_names do
		if str.StartsWith(section_names[i], 'Flag:' .. mode .. ':') then
			local parts = str.Split(section_names[i], ':')
			if #parts == 3 then
				overlays[parts[3]] = self:_load_overlay(mode, parts[3])
			end
		end
	end
	return overlays
end

function SpellBarConfig:_load_mode(mode, section_names)
	if common.TableHasValue(section_names, 'Mode:' .. mode) then
		local raw_string = self.Ini:Section('Mode:' .. mode):String('SpellBar')
		local gems = str.Split(raw_string, ',')
		local mode_data = {}
		for j=1,#gems do
			local gem = str.Split(gems[j], ':')
			mode_data[tonumber(gem[1])] = gem[2]
		end
		return mode_data
	end
	return {}
end

function SpellBarConfig:Load()
	local section_names = self.Ini:SectionNames()
	self.Defaults = self:_load_defaults(section_names)
	for i=2,4 do
		self.Modes[i] = self:_load_mode(i, section_names)
		self.ModeOverlays[i] = self:_load_overlays_by_mode(i, section_names)
	end
	self._last_load_time = mq.gettime()
end

function SpellBarConfig:Reload(min_interval)
	if mq.gettime() >= self._last_load_time + (min_interval or 10000) then
		self:Load()
	end
end

function SpellBarConfig:Gems(state_config)
	local mode = state_config:Mode()
	local flags = state_config:Flags()
	local overlaid = {}
	for k,v in pairs(self.Defaults) do
		overlaid[k] = v
	end
	if self.Modes[mode] then
		for k,v in pairs(self.Modes[mode]) do
			overlaid[k] = v
		end
	end
	for i=1,#flags do
		local flag_overlay = self.ModeOverlays[mode][flags[i]] or {}
		for k,v in pairs(flag_overlay) do
			overlaid[k] = v
		end
	end
	return overlaid
end

function SpellBarConfig:GemAndSpellByKey(state_config, spells_config, spell_key)
	if spell_key == '' then
		return -3, '', 'Spell not defined'
	else
		local ref = spells_config:Spell(spell_key)
		if ref == '' then
			return -2, '', 'Cannot find spell key: ' .. spell_key
		else
			local spell_name = spells.ReferenceSpell(ref)
			if spell_name == '' then
				return -1, '', 'Cannot find spell for reference: ' .. ref
			else
				local gem = self:GemBySpellKey(state_config, spell_key)
				if gem == 0 then gem = self:FirstOpenGem(state_config) end
				if gem == 0 then
					return 0, spell_name, 'Cannot find gem for key: ' .. spell_key
				else
					return gem, spell_name, ''
				end
			end
		end
	end
end

function SpellBarConfig:SpellKeyByGem(state_config, gem)
	local spell_bar = self:Gems(state_config)
	return spell_bar[gem]
end

function SpellBarConfig:GemBySpellKey(state_config, spell)
	local spell_bar = self:Gems(state_config)
	for k,v in pairs(spell_bar) do
		if spell == v then return k end
	end
	return 0
end

function SpellBarConfig:FirstOpenGem(state_config)
	local spell_bar = self:Gems(state_config)
	for k,v in pairs(spell_bar) do
		if 'OPEN' == v then return k end
	end
	return 0
end


local function load_overlay(ini, type, mode, flag)
	local section = ini:Section('Flag:' .. mode .. ':' .. flag .. ':' .. type)
	return section:ToTable()
end

local function load_overlays_by_mode(ini, type, mode, section_names)
	local overlays = {}
	for i=1,#section_names do
		if str.StartsWith(section_names[i], 'Flag:' .. mode .. ':') and str.EndsWith(section_names[i], ':' .. type) then
			local parts = str.Split(section_names[i], ':')
			if #parts == 4 then
				overlays[parts[3]] = load_overlay(ini, type, mode, parts[3])
			end
		end
	end
	return overlays
end

local function load_mode(ini, type, mode, section_names)
	local mode_data = {}
	local section_name = 'Mode:' .. mode .. ':' .. type
	if common.TableHasValue(section_names, section_name) then
		local section = ini:Section(section_name)
		mode_data = section:ToTable()
	end
	return mode_data
end

local function load_defaults(ini, type, section_names)
	local defaults = {}
	if common.TableHasValue(section_names, 'Default:' .. type) then
		local section = ini:Section('Default:' .. type)
		defaults = section:ToTable()
	end
	return defaults
end

local function mode_value(defaults, modes, overlays, mode, flags, key, default)
	if not flags then flags = {} end
	local value = defaults[key]
	if modes[mode] then
		if modes[mode][key] then
			value = modes[mode][key]
		end
		for i=1,#flags do
			if overlays[mode][flags[i]] and overlays[mode][flags[i]][key] then
				value = overlays[mode][flags[i]][key]
			end
		end
	end

	return value or default
end


--
-- State
--

StateConfig = {}
StateConfig.__index = StateConfig

function StateConfig:new(persist)
	local mt = {}
	setmetatable(mt, self)

	mt._persist = persist or false

	mt._mode = 1
	mt._flags = {}
	mt._ini_section = Ini:new():Section('State')
	mt:Load()

	return mt
end

function StateConfig:Load()
	self._mode = self._ini_section:Number('Mode', 1)
	self._flags = str.Split(self._ini_section:String('Flags', ''), ',')
end

function StateConfig:Mode()
	return self._mode
end

function StateConfig:Flags()
	return self._flags
end

function StateConfig:UpdateMode(mode)
	self._mode = mode
	if self._persist then
		self._ini_section:WriteNumber('Mode', self._mode)
	end
end

function StateConfig:SetFlag(flag)
	if not common.TableHasValue(self._flags, flag) then
		table.insert(self._flags, flag)
		if self._persist then
			local csv = common.TableAsCsv(self._flags)
			self._ini_section:WriteString('Flags', csv)
		end
	end
end

function StateConfig:UnsetFlag(flag)
	local idx = common.TableIndexOf(self._flags, flag)
	if idx > 0 then
		table.remove(self._flags, idx)
		if self._persist then
			local csv = common.TableAsCsv(self._flags)
			self._ini_section:WriteString('Flags', csv)
		end
	end
end


--
-- Cast Queue
--

CastQueueConfig = {}
CastQueueConfig.__index = CastQueueConfig

function CastQueueConfig:new()
	local mt = {}
	setmetatable(mt, self)

	mt.Defaults = {}
	mt.Modes = {}
	mt.Overlays = {}
	mt.Ini = Ini:new()
	mt:Load()

	return mt
end

function CastQueueConfig:Load()
	local type = 'CastQueue'
	local section_names = self.Ini:SectionNames()
	self.Defaults = load_defaults(self.Ini, type, section_names)
	for i=2,4 do
		self.Modes[i] = load_mode(self.Ini, type, i, section_names)
		self.Overlays[i] = load_overlays_by_mode(self.Ini, type, i, section_names)
	end
	self._last_load_time = mq.gettime()
end

function CastQueueConfig:Reload(min_interval)
	if mq.gettime() >= self._last_load_time + (min_interval or 10000) then
		self:Load()
	end
end

function CastQueueConfig:_mode_value(state_config, key, default)
	return mode_value(self.Defaults, self.Modes, self.Overlays, state_config:Mode(), state_config:Flags(), key, default)
end

function CastQueueConfig:Print(state_config)
	return self:_mode_value(state_config, 'Print', 'FALSE') == 'TRUE'
end

function CastQueueConfig:PrintTimer(state_config)
	return tonumber(self:_mode_value(state_config, 'PrintTimer', '10'))
end


--
-- Autosit
--

AutoSitConfig = {}
AutoSitConfig.__index = AutoSitConfig

function AutoSitConfig:new()
	local mt = {}
	setmetatable(mt, self)

	mt.Defaults = {}
	mt.Modes = {}
	mt.Overlays = {}
	mt.Ini = Ini:new()
	mt:Load()

	return mt
end

function AutoSitConfig:Load()
	local type = 'AutoSit'
	local section_names = self.Ini:SectionNames()
	self.Defaults = load_defaults(self.Ini, type, section_names)
	for i=2,4 do
		self.Modes[i] = load_mode(self.Ini, type, i, section_names)
		self.Overlays[i] = load_overlays_by_mode(self.Ini, type, i, section_names)
	end
	self._last_load_time = mq.gettime()
end

function AutoSitConfig:Reload(min_interval)
	if mq.gettime() >= self._last_load_time + (min_interval or 10000) then
		self:Load()
	end
end

function AutoSitConfig:_mode_value(state_config, key, default)
	return mode_value(self.Defaults, self.Modes, self.Overlays, state_config:Mode(), state_config:Flags(), key, default)
end

function AutoSitConfig:Enabled(state_config)
	return self:_mode_value(state_config, 'Enabled', 'FALSE') == 'TRUE'
end

function AutoSitConfig:MinHPs(state_config)
	return tonumber(self:_mode_value(state_config, 'MinHPs', '95'))
end

function AutoSitConfig:MinMana(state_config)
	return tonumber(self:_mode_value(state_config, 'MinMana', '95'))
end

function AutoSitConfig:OverrideOnMove(state_config)
	return self:_mode_value(state_config, 'Enabled', 'OverrideOnMove') == 'TRUE'
end

function AutoSitConfig:OverrideSeconds(state_config)
	return tonumber(self:_mode_value(state_config, 'OverrideSeconds', '10'))
end


--
-- Buff
--

BuffConfig = {}
BuffConfig.__index = BuffConfig

function BuffConfig:new()
	local mt = {}
	setmetatable(mt, self)

	mt.Defaults = {}
	mt.Modes = {}
	mt.Overlays = {}
	mt.Ini = Ini:new()
	mt:Load()

	return mt
end

function BuffConfig:Load()
	local type = 'Buff'
	local section_names = self.Ini:SectionNames()
	self.Defaults = load_defaults(self.Ini, type, section_names)
	for i=2,4 do
		self.Modes[i] = load_mode(self.Ini, type, i, section_names)
		self.Overlays[i] = load_overlays_by_mode(self.Ini, type, i, section_names)
	end
	self._last_load_time = mq.gettime()
end

function BuffConfig:Reload(min_interval)
	if mq.gettime() >= self._last_load_time + (min_interval or 10000) then
		self:Load()
	end
end

function BuffConfig:_mode_value(state_config, key, default)
	return mode_value(self.Defaults, self.Modes, self.Overlays, state_config:Mode(), state_config:Flags(), key, default)
end

function BuffConfig:Enabled(state_config)
	return self:_mode_value(state_config, 'Enabled', 'FALSE') == 'TRUE'
end

function BuffConfig:MinMana(state_config)
	return tonumber(self:_mode_value(state_config, 'MinMana', '45'))
end

function BuffConfig:Backoff(state_config)
	return self:_mode_value(state_config, 'Backoff', 'TRUE') == 'TRUE'
end

function BuffConfig:BackoffTimer(state_config)
	return tonumber(self:_mode_value(state_config, 'BackoffTimer', '300')) * 1000
end

function BuffConfig:TankPackage(state_config)
	return str.Split(self:_mode_value(state_config, 'Tank', ''), ',')
end

function BuffConfig:MeleePackage(state_config)
	return str.Split(self:_mode_value(state_config, 'Melee', ''), ',')
end

function BuffConfig:CasterPackage(state_config)
	return str.Split(self:_mode_value(state_config, 'Caster', ''), ',')
end

function BuffConfig:PetPackage(state_config)
	return str.Split(self:_mode_value(state_config, 'Pet', ''), ',')
end

function BuffConfig:SelfPackage(state_config)
	return str.Split(self:_mode_value(state_config, 'Self', ''), ',')
end

function BuffConfig:SelfpetPackage(state_config)
	return str.Split(self:_mode_value(state_config, 'Selfpet', ''), ',')
end


CrowdControlConfig = {}
CrowdControlConfig.__index = CrowdControlConfig

function CrowdControlConfig:new()
	local mt = {}
	setmetatable(mt, self)

	mt.Defaults = {}
	mt.Modes = {}
	mt.Overlays = {}
	mt.Ini = Ini:new()
	mt:Load()

	return mt
end

function CrowdControlConfig:Load()
	local type = 'CrowdControl'
	local section_names = self.Ini:SectionNames()
	self.Defaults = load_defaults(self.Ini, type, section_names)
	for i=2,4 do
		self.Modes[i] = load_mode(self.Ini, type, i, section_names)
		self.Overlays[i] = load_overlays_by_mode(self.Ini, type, i, section_names)
	end
	self._last_load_time = mq.gettime()
end

function CrowdControlConfig:Reload(min_interval)
	if mq.gettime() >= self._last_load_time + (min_interval or 10000) then
		self:Load()
	end
end

function CrowdControlConfig:_mode_value(state_config, key, default)
	return mode_value(self.Defaults, self.Modes, self.Overlays, state_config:Mode(), state_config:Flags(), key, default)
end

function CrowdControlConfig:Enabled(state_config)
	return self:_mode_value(state_config, 'Enabled', 'FALSE') == 'TRUE'
end

function CrowdControlConfig:MinMana(state_config)
	return tonumber(self:_mode_value(state_config, 'MinMana', '10'))
end

function CrowdControlConfig:IAmPrimary(state_config)
	return self:_mode_value(state_config, 'IAmPrimary', 'FALSE') == 'TRUE'
end

function CrowdControlConfig:Spell(state_config)
	return self:_mode_value(state_config, 'Spell', '')
end


DebuffConfig = {}
DebuffConfig.__index = DebuffConfig

function DebuffConfig:new()
	local mt = {}
	setmetatable(mt, self)

	mt.Defaults = {}
	mt.Modes = {}
	mt.Overlays = {}
	mt.Ini = Ini:new()
	mt:Load()

	return mt
end

function DebuffConfig:Load()
	local type = 'Debuff'
	local section_names = self.Ini:SectionNames()
	self.Defaults = load_defaults(self.Ini, type, section_names)
	for i=2,4 do
		self.Modes[i] = load_mode(self.Ini, type, i, section_names)
		self.Overlays[i] = load_overlays_by_mode(self.Ini, type, i, section_names)
	end
	self._last_load_time = mq.gettime()
end

function DebuffConfig:Reload(min_interval)
	if mq.gettime() >= self._last_load_time + (min_interval or 10000) then
		self:Load()
	end
end

function DebuffConfig:_mode_value(state_config, key, default)
	return mode_value(self.Defaults, self.Modes, self.Overlays, state_config:Mode(), state_config:Flags(), key, default)
end

function DebuffConfig:Enabled(state_config)
	return self:_mode_value(state_config, 'Enabled', 'FALSE') == 'TRUE'
end

function DebuffConfig:MinMana(state_config)
	return tonumber(self:_mode_value(state_config, 'MinMana', '45'))
end

function DebuffConfig:MinTargetHpPct(state_config)
	return tonumber(self:_mode_value(state_config, 'MinTargetHpPct', '65'))
end

function DebuffConfig:AtTargetHpPcts(state_config)
	local csv = str.Split(self:_mode_value(state_config, 'Pcts', ''), ',')
	local pcts = {}
	for i,s in ipairs(csv) do
		local parts = str.Split(s, ':')
		pcts[tonumber(parts[2])] = parts[1]
	end
	return pcts
end


DotConfig = {}
DotConfig.__index = DotConfig

function DotConfig:new()
	local mt = {}
	setmetatable(mt, self)

	mt.Defaults = {}
	mt.Modes = {}
	mt.Overlays = {}
	mt.Ini = Ini:new()
	mt:Load()

	return mt
end

function DotConfig:Load()
	local type = 'Dot'
	local section_names = self.Ini:SectionNames()
	self.Defaults = load_defaults(self.Ini, type, section_names)
	for i=2,4 do
		self.Modes[i] = load_mode(self.Ini, type, i, section_names)
		self.Overlays[i] = load_overlays_by_mode(self.Ini, type, i, section_names)
	end
	self._last_load_time = mq.gettime()
end

function DotConfig:Reload(min_interval)
	if mq.gettime() >= self._last_load_time + (min_interval or 10000) then
		self:Load()
	end
end

function DotConfig:_mode_value(state_config, key, default)
	return mode_value(self.Defaults, self.Modes, self.Overlays, state_config:Mode(), state_config:Flags(), key, default)
end

function DotConfig:Enabled(state_config)
	return self:_mode_value(state_config, 'Enabled', 'FALSE') == 'TRUE'
end

function DotConfig:MinMana(state_config)
	return tonumber(self:_mode_value(state_config, 'MinMana', '50'))
end

function DotConfig:MinTargetHpPct(state_config)
	return tonumber(self:_mode_value(state_config, 'MinTargetHpPct', '65'))
end

function DotConfig:AtTargetHpPcts(state_config)
	local csv = str.Split(self:_mode_value(state_config, 'Pcts', ''), ',')
	local pcts = {}
	for i,s in ipairs(csv) do
		local parts = str.Split(s, ':')
		pcts[tonumber(parts[2])] = parts[1]
	end
	return pcts
end


HealConfig = {}
HealConfig.__index = HealConfig

function HealConfig:new()
	local mt = {}
	setmetatable(mt, self)

	mt.Defaults = {}
	mt.Modes = {}
	mt.Overlays = {}
	mt.Ini = Ini:new()
	mt:Load()

	return mt
end

function HealConfig:Load()
	local type = 'Heal'
	local section_names = self.Ini:SectionNames()
	self.Defaults = load_defaults(self.Ini, type, section_names)
	for i=2,4 do
		self.Modes[i] = load_mode(self.Ini, type, i, section_names)
		self.Overlays[i] = load_overlays_by_mode(self.Ini, type, i, section_names)
	end
	self._last_load_time = mq.gettime()
end

function HealConfig:Reload(min_interval)
	if mq.gettime() >= self._last_load_time + (min_interval or 10000) then
		self:Load()
	end
end

function HealConfig:_mode_value(state_config, key, default)
	return mode_value(self.Defaults, self.Modes, self.Overlays, state_config:Mode(), state_config:Flags(), key, default)
end

function HealConfig:Enabled(state_config)
	return self:_mode_value(state_config, 'Enabled', 'FALSE') == 'TRUE'
end

function HealConfig:MinMana(state_config)
	return tonumber(self:_mode_value(state_config, 'MinMana', '0'))
end

function HealConfig:AtHpPct(type, state_config)
	local parts = str.Split(self:_mode_value(state_config, type, ''), ':')
	if #parts == 2 then
		return tonumber(parts[2]), parts[1]
	else
		return 0, ''
	end
end

function HealConfig:GroupAtHpPct(state_config)
	return self:AtHpPct('Group', state_config)
end

function HealConfig:TankAtHpPct(state_config)
	return self:AtHpPct('Tank', state_config)
end

function HealConfig:MeleeAtHpPct(state_config)
	return self:AtHpPct('Melee', state_config)
end

function HealConfig:CasterAtHpPct(state_config)
	return self:AtHpPct('Caster', state_config)
end

function HealConfig:PetAtHpPct(state_config)
	return self:AtHpPct('Pet', state_config)
end

function HealConfig:SelfAtHpPct(state_config)
	return self:AtHpPct('Self', state_config)
end

function HealConfig:SelfpetAtHpPct(state_config)
	return self:AtHpPct('Selfpet', state_config)
end


--
-- Melee
--

MeleeConfig = {}
MeleeConfig.__index = MeleeConfig

function MeleeConfig:new()
	local mt = {}
	setmetatable(mt, self)

	mt.Defaults = {}
	mt.Modes = {}
	mt.Overlays = {}
	mt.Ini = Ini:new()
	mt:Load()

	return mt
end

function MeleeConfig:Load()
	local type = 'Melee'
	local section_names = self.Ini:SectionNames()
	self.Defaults = load_defaults(self.Ini, type, section_names)
	for i=2,4 do
		self.Modes[i] = load_mode(self.Ini, type, i, section_names)
		self.Overlays[i] = load_overlays_by_mode(self.Ini, type, i, section_names)
	end
	self._last_load_time = mq.gettime()
end

function MeleeConfig:Reload(min_interval)
	if mq.gettime() >= self._last_load_time + (min_interval or 10000) then
		self:Load()
	end
end

function MeleeConfig:_mode_value(state_config, key, default)
	return mode_value(self.Defaults, self.Modes, self.Overlays, state_config:Mode(), state_config:Flags(), key, default)
end

function MeleeConfig:Enabled(state_config)
	return self:_mode_value(state_config, 'Enabled', 'FALSE') == 'TRUE'
end

function MeleeConfig:EngageTargetHPs(state_config)
	return tonumber(self:_mode_value(state_config, 'EngageTargetHPs', '95'))
end

function MeleeConfig:EngageTargetDistance(state_config)
	return tonumber(self:_mode_value(state_config, 'EngageTargetDistance', '75'))
end


--
-- DD
--

DdConfig = {}
DdConfig.__index = DdConfig

function DdConfig:new()
	local mt = {}
	setmetatable(mt, self)

	mt.Defaults = {}
	mt.Modes = {}
	mt.Overlays = {}
	mt.Ini = Ini:new()
	mt:Load()

	return mt
end

function DdConfig:Load()
	local type = 'DD'
	local section_names = self.Ini:SectionNames()
	self.Defaults = load_defaults(self.Ini, type, section_names)
	for i=2,4 do
		self.Modes[i] = load_mode(self.Ini, type, i, section_names)
		self.Overlays[i] = load_overlays_by_mode(self.Ini, type, i, section_names)
	end
	self._last_load_time = mq.gettime()
end

function DdConfig:Reload(min_interval)
	if mq.gettime() >= self._last_load_time + (min_interval or 10000) then
		self:Load()
	end
end

function DdConfig:_mode_value(state_config, key, default)
	return mode_value(self.Defaults, self.Modes, self.Overlays, state_config:Mode(), state_config:Flags(), key, default)
end

function DdConfig:Enabled(state_config)
	return self:_mode_value(state_config, 'Enabled', 'FALSE') == 'TRUE'
end

function DdConfig:MinMana(state_config)
	return tonumber(self:_mode_value(state_config, 'MinMana', '50'))
end

function DdConfig:MinTargetHpPct(state_config)
	return tonumber(self:_mode_value(state_config, 'MinTargetHpPct', '0'))
end

function DdConfig:AtTargetHpPcts(state_config)
	local csv = str.Split(self:_mode_value(state_config, 'Pcts', ''), ',')
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

function PetConfig:new()
	local mt = {}
	setmetatable(mt, self)

	mt.DefaultPetType = default_pet_type()

	mt.Defaults = {}
	mt.Modes = {}
	mt.Overlays = {}
	mt.Ini = Ini:new()
	mt:Load()

	return mt
end

function PetConfig:Load()
	local type = 'Pet'
	local section_names = self.Ini:SectionNames()
	self.Defaults = load_defaults(self.Ini, type, section_names)
	for i=2,4 do
		self.Modes[i] = load_mode(self.Ini, type, i, section_names)
		self.Overlays[i] = load_overlays_by_mode(self.Ini, type, i, section_names)
	end
	self._last_load_time = mq.gettime()
end

function PetConfig:Reload(min_interval)
	if mq.gettime() >= self._last_load_time + (min_interval or 10000) then
		self:Load()
	end
end

function PetConfig:_mode_value(state_config, key, default)
	return mode_value(self.Defaults, self.Modes, self.Overlays, state_config:Mode(), state_config:Flags(), key, default)
end

function PetConfig:AutoCast(state_config)
	return self:_mode_value(state_config, 'AutoCast', 'FALSE') == 'TRUE'
end

function PetConfig:AutoAttack(state_config)
	return self:_mode_value(state_config, 'AutoAttack', 'FALSE') == 'TRUE'
end

function PetConfig:Type(state_config)
	return self:_mode_value(state_config, 'Type', self.DefaultPetType)
end

function PetConfig:MinMana(state_config)
	return tonumber(self:_mode_value(state_config, 'MinMana', '50'))
end

function PetConfig:EngageTargetHPs(state_config)
	return tonumber(self:_mode_value(state_config, 'EngageTargetHPs', '95'))
end

function PetConfig:EngageTargetDistance(state_config)
	return tonumber(self:_mode_value(state_config, 'EngageTargetDistance', '75'))
end


--
-- Twist
--

TwistConfig = {}
TwistConfig.__index = TwistConfig

function TwistConfig:new()
	local mt = {}
	setmetatable(mt, self)

	mt.Defaults = {}
	mt.Modes = {}
	mt.Overlays = {}
	mt.Ini = Ini:new()
	mt:Load()

	return mt
end

function TwistConfig:Load()
	local type = 'Twist'
	local section_names = self.Ini:SectionNames()
	self.Defaults = load_defaults(self.Ini, type, section_names)
	for i=2,4 do
		self.Modes[i] = load_mode(self.Ini, type, i, section_names)
		self.Overlays[i] = load_overlays_by_mode(self.Ini, type, i, section_names)
	end
	self._last_load_time = mq.gettime()
end

function TwistConfig:Reload(min_interval)
	if mq.gettime() >= self._last_load_time + (min_interval or 10000) then
		self:Load()
	end
end

function TwistConfig:_mode_value(state_config, key, default)
	return mode_value(self.Defaults, self.Modes, self.Overlays, state_config:Mode(), state_config:Flags(), key, default)
end

function TwistConfig:Enabled(state_config)
	return self:_mode_value(state_config, 'Enabled', 'FALSE') == 'TRUE'
end

function TwistConfig:Order(state_config)
	return str.Split(self:_mode_value(state_config, 'Order', ''), ',')
end

function TwistConfig:CombatOrder(state_config)
	return str.Split(self:_mode_value(state_config, 'CombatOrder', ''), ',')
end
