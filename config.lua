local mq = require('mq')
local str = require('str')
local co = require('co')
require('either')
require('ini')
require('eqclass')
require('castable')
local array = require('array')

MyClass = EQClass:new()

if not table.unpack then table.unpack = unpack end

local function pack(...)
	return { ... }
end

local function memoized1(fn)
	local cached = nil
	return function()
		if cached == nil then
			cached = fn()
			-- cached = pack(fn())
		end
		return cached
		-- return table.unpack(cached)
	end
end

local function memoized(fn)
	local cache = {}

	return function(...)
	  local args = {...}
	  local key = args[1]

	  if key.IsCastable ~= nil and key.IsCastable then
		key = key.AsString()
	  end
	  if not cache[key] then
		cache[key] = fn(...)
		-- cache[key] = pack(fn(...))
	  end

	  return cache[key]
	  -- return table.unpack(cache[key])
	end
end


function Config(state, ini)
	local self = {}
	self.__type__ = 'Config'

	self.Spells = SpellsConfig(state, ini)
	self.SpellBar = SpellBarConfig(state, ini, self.Spells)
	self.CastQueue = CastQueueConfig(state, ini)
	self.AutoSit = AutoSitConfig(state, ini)
	self.Tether = TetherConfig(state, ini)
	self.Twist = TwistConfig(state, ini)
	self.TeamEvents = TeamEventsConfig(state, ini)
	self.Heal = HealConfig(state, ini)
	self.Melee = MeleeConfig(state, ini)
	self.Pet = PetConfig(state, ini)
	self.Debuff = DebuffConfig(state, ini)
	self.CrowdControl = CrowdControlConfig(state, ini)
	self.Buff = BuffConfig(state, ini)
	self.CombatBuff = CombatBuffConfig(state, ini)
	self.Dot = DotConfig(state, ini)
	self.Dd = DdConfig(state, ini)

	local last_load_time = mq.gettime()

	self.Refresh = function()
		self.CastQueue.RefreshFuncs()
		co.yield()
		self.Tether.RefreshFuncs()
		co.yield()
		self.TeamEvents.RefreshFuncs()
		co.yield()
		self.AutoSit.RefreshFuncs()
		co.yield()
		self.Melee.RefreshFuncs()
		co.yield()
		self.CrowdControl.RefreshFuncs()
		co.yield()
		self.Debuff.RefreshFuncs()
		co.yield()
		self.Heal.RefreshFuncs()
		co.yield()
		self.Pet.RefreshFuncs()
		co.yield()
		self.Buff.RefreshFuncs()
		co.yield()
		self.CombatBuff.RefreshFuncs()
		co.yield()
		self.Dot.RefreshFuncs()
		co.yield()
		self.Dd.RefreshFuncs()
		co.yield()
		if MyClass.HasSpells or MyClass.IsBard then
			self.SpellBar.RefreshFuncs()
			co.yield()
		end
		if MyClass.IsBard then
			self.Twist.RefreshFuncs()
			co.yield()
		end
	end

	self.Reload = function(min_interval)
		if mq.gettime() >= last_load_time + (min_interval or 10000) then
			ini:Reload()

			co.yield()

			self.CastQueue.Calculate()
			co.yield()
			self.Tether.Calculate()
			co.yield()
			self.TeamEvents.Calculate()
			co.yield()
			self.AutoSit.Calculate()
			co.yield()
			self.Melee.Calculate()
			co.yield()
			self.CrowdControl.Calculate()
			co.yield()
			self.Debuff.Calculate()
			co.yield()
			self.Heal.Calculate()
			co.yield()
			self.Pet.Calculate()
			co.yield()
			self.Buff.Calculate()
			co.yield()
			self.CombatBuff.Calculate()
			co.yield()
			self.Dot.Calculate()
			co.yield()
			self.Dd.Calculate()
			co.yield()
			if MyClass.HasSpells or MyClass.IsBard then
				self.SpellBar.Calculate()
				co.yield()
			end
			if MyClass.IsBard then
				self.Twist.Calculate()
				co.yield()
			end

			last_load_time = mq.gettime()
		end
	end

	return self
end


--
-- Spells
--

function SpellsConfig(state, ini)
	local self = {}
	self.__type__ = 'SpellsConfig'

	self.Spell = function(spell_key_or_ref)
		assert(spell_key_or_ref ~= nil, 'Tried to look up spell with nil value')

		local spell_value = ini:String('Spells', spell_key_or_ref, '')
		if #spell_value > 0 then
			return CastableFromKey(spell_key_or_ref, spell_value)
		else
			return CastableFromRef(spell_key_or_ref)
		end
	end

	return self
end


--
-- SpellBar
--

function SpellBarConfig(state, ini, spells_config)
	local self = {}
	self.__type__ = 'SpellBarConfig'

	local defaults = {}
	local mode_overlays = {}
	local flag_overlays = {}
	local flag_overlays_open_fills = {}
	local mode_flag_overlays = {}
	local mode_flag_overlays_open_fills = {}
	local last_load_time = mq.gettime()

	local function split_gems(spell_bar)
		local value = {}
		local to_fill = {}
		local gems = str.Split(spell_bar, ',')
		for i, gem in ipairs(gems) do
			local idx = gem:find(':')
			local slot = gem:sub(1, idx - 1)
			local ref = gem:sub(idx + 1, -1)
			if slot == 'O' or slot == '0' then
				table.insert(to_fill, ref)
			else
				value[tonumber(slot)] = ref
			end
		end
		return value, to_fill
	end

	local function defaults_from_ini()
		local values, to_fill = split_gems(ini:String('Default', 'SpellBar', ''))
		for i=1,mq.TLO.Me.NumGems() do
			if not values[i] then values[i] = 'OPEN' end
		end
		return values
	end

	local function flag_overlays_from_ini()
		local overlays = {}
		local open_fills = {}
		for i, name in ipairs(ini:SectionNames()) do
			if str.StartsWith(name, 'Flag:') then
				local parts = str.Split(name, ':')
				if #parts == 2 and not tonumber(parts[2]) then
					local to_fill = {}
					overlays[parts[2]], open_fills[parts[2]] = split_gems(ini:String(name, 'SpellBar', ''))
				end
			end
		end
		return overlays, open_fills
	end

	local function mode_flag_overlays_from_ini(mode)
		local overlays = {}
		local open_fills = {}
		for i, section_name in ipairs(ini:SectionNames()) do
			if str.StartsWith(section_name, 'Flag:' .. mode .. ':') then
				local parts = str.Split(section_name, ':')
				if #parts == 3 then
					local to_fill = {}
					overlays[parts[3]], open_fills[parts[3]] = split_gems(ini:String(section_name, 'SpellBar', ''))
				end
			end
		end
		return overlays, open_fills
	end

	local function mode_overlays_from_ini(mode)
		local overlays, to_fill = split_gems(ini:String('Mode:' .. mode, 'SpellBar', ''))
		return overlays
	end

	local function gems()
		local mode = state.Mode

		local overlaid = {}
		local open_overlaid = {}
		for k,v in pairs(defaults) do
			if k ~= 0 then
				overlaid[k] = v
			end
		end
		for k,v in pairs(mode_overlays[mode] or {}) do
			if k ~= 0 then
				overlaid[k] = v
			end
		end
		for i, flag in ipairs(state.Flags) do
			local flag_overlay = flag_overlays[flag] or {}
			local flag_overlay_open_fills = flag_overlays_open_fills[flag] or {}
			for k, v in pairs(flag_overlay) do
				overlaid[k] = v
			end
			for k, ref in ipairs(flag_overlay_open_fills) do
				table.insert(open_overlaid, ref)
			end
			local mode_flag_overlay = mode_flag_overlays[mode][flag] or {}
			local mode_flag_overlay_open_fills = mode_flag_overlays_open_fills[mode][flag] or {}
			for k, v in pairs(mode_flag_overlay) do
				overlaid[k] = v
			end
			for k, ref in ipairs(mode_flag_overlay_open_fills) do
				table.insert(open_overlaid, ref)
			end
		end
		for i, open_ref in ipairs(open_overlaid) do
			for j, ref in ipairs(overlaid) do
				if ref:upper() == 'OPEN' then
					overlaid[j] = open_ref
					break
				end
			end
		end
		return overlaid
	end

	local function spell_key_by_gem(gem)
		local spell_bar = self.Gems()
		return spell_bar[gem]
	end

	local function gem_by_spell_key(spell_key)
		local spell_bar = self.Gems()
		for k,v in pairs(spell_bar) do
			if spell_key == v then return k end
		end
		return 0
	end

	local function gem_by_spell(spell)
		if spell.Error ~= nil then
			return { gem = -1, msg = spell.Error }
		else
			if spell.Name == '' then
				return { gem = -2, msg = 'Spell not defined' }
			else
				local gem = 0
				if spell.Key ~= nil then
					gem = self.GemBySpellKey(spell.Key)
				else
					gem = self.GemBySpellName(spell.Name)
				end
				if gem == 0 then gem = self.FirstOpenGem() end
				if gem == 0 then
					return { gem = 0, msg = 'Cannot find gem for key: ' .. spell.Key }
				else
					return { gem = gem, msg = '' }
				end
			end
		end
	end

	local function gem_by_spell_name(spell_name)
		local spell_bar = self.Gems()
		for gem, spell_key in pairs(spell_bar) do
			if spells_config.Spell(spell_key).Name == spell_name then return gem end
		end
		return 0
	end

	local function first_open_gem()
		local spell_bar = self.Gems()
		for k,v in pairs(spell_bar) do
			if 'OPEN' == v then return k end
		end
		return 0
	end

	self.Calculate = function()
		local start = mq.gettime()
		defaults = defaults_from_ini()
		flag_overlays, flag_overlays_open_fills = flag_overlays_from_ini()
		for i=1,4 do
			mode_overlays[i] = mode_overlays_from_ini(i)
			mode_flag_overlays[i], mode_flag_overlays_open_fills[i] = mode_flag_overlays_from_ini(i)
		end
		last_load_time = mq.gettime()

		self.RefreshFuncs()
	end

	self.RefreshFuncs = function()
		self.Gems = memoized1(gems)
		self.GemBySpell = memoized(gem_by_spell)
		self.SpellKeyByGem = memoized(spell_key_by_gem)
		self.GemBySpellKey = memoized(gem_by_spell_key)
		self.GemBySpellName = memoized(gem_by_spell_name)
		self.FirstOpenGem = memoized1(first_open_gem)
	end

	self.Calculate()

	return self
end


local function mode_flag_overlays_from_ini(ini, type, mode)
	local overlays = {}
	for i, section_name in ipairs(ini:SectionNames()) do
		if str.StartsWith(section_name, 'Flag:' .. mode .. ':') and str.EndsWith(section_name, ':' .. type) then
			local parts = str.Split(section_name, ':')
			if #parts == 4 then
				overlays[parts[3]] = ini:Section(section_name).ToTable() or {}
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
				overlays[parts[2]] = ini:Section(section_name).ToTable() or {}
			end
		end
	end
	return overlays
end

local function mode_overlays_from_ini(ini, type, mode)
	return ini:Section('Mode:' .. mode .. ':' .. type).ToTable() or {}
end

local function defaults_from_ini(ini, type)
	return ini:Section('Default:' .. type).ToTable() or {}
end

local function mode_value(state, defaults, mode_overlays, flag_overlays, mode_flag_overlays, key, default)
	local value = defaults[key]
	if mode_overlays[state.Mode] ~= nil then
		if mode_overlays[state.Mode][key] ~= nil then
			value = mode_overlays[state.Mode][key]
		end
	end
	for i, flag in ipairs(state.Flags) do
		if flag_overlays[flag] ~= nil and flag_overlays[flag][key] ~= nil then
			value = flag_overlays[flag][key]
		end
	end
	if mode_flag_overlays[state.Mode] ~= nil then
		for i, flag in ipairs(state.Flags) do
			if mode_flag_overlays[state.Mode][flag] ~= nil and mode_flag_overlays[state.Mode][flag][key] ~= nil then
				value = mode_flag_overlays[state.Mode][flag][key]
			end
		end
	end

	return value or default
end

local function overlay_csv(values_arr, overlay_str)
	if overlay_str:sub(1, 1) == '+' then
		local overlay_arr = str.Split(overlay_str:sub(2), ',')
		for i, o in ipairs(overlay_arr) do
			if o:sub(1, 1) == '-' then
				local to_remove = o:sub(2)
				local idx = 0
				for j, v in ipairs(values_arr) do
					if v == to_remove then
						idx = j
						break
					end
				end
				if idx ~= 0 then
					table.remove(values_arr, idx)
				end
			else
				table.insert(values_arr, o)
			end
		end
		return values_arr
	else
		return str.Split(overlay_str, ',')
	end
end

local function csv_mode_value(state, defaults, mode_overlays, flag_overlays, mode_flag_overlays, key, default)
	local values = str.Split(defaults[key] or '', ',')
	if mode_overlays[state.Mode] ~= nil then
		if mode_overlays[state.Mode][key] ~= nil then
			values = overlay_csv(values, mode_overlays[state.Mode][key])
		end
	end
	for i, flag in ipairs(state.Flags) do
		if flag_overlays[flag] ~= nil and flag_overlays[flag][key] ~= nil then
			values = overlay_csv(values, flag_overlays[flag][key])
		end
	end
	if mode_flag_overlays[state.Mode] ~= nil then
		for i, flag in ipairs(state.Flags) do
			if mode_flag_overlays[state.Mode][flag] ~= nil and mode_flag_overlays[state.Mode][flag][key] ~= nil then
				values = overlay_csv(values, mode_flag_overlays[state.Mode][flag][key])
			end
		end
	end

	return values or default
end


--
-- Base
--

function GenericConfig(state, ini, ini_key)
	local self = {}
	self.__type__ = 'GenericConfig'

	local defaults = {}
	local mode_overlays = {}
	local flag_overlays = {}
	local mode_flag_overlays = {}
	local last_load_time = mq.gettime()

	self._value = function(key, default)
		return mode_value(state, defaults, mode_overlays, flag_overlays, mode_flag_overlays, key, default)
	end

	self._csv_value = function(key)
		return csv_mode_value(state, defaults, mode_overlays, flag_overlays, mode_flag_overlays, key, {})
	end

	self.RefreshFuncs = function() end

	self.Calculate = function()
		defaults = defaults_from_ini(ini, ini_key)
		flag_overlays = flag_overlays_from_ini(ini, ini_key)
		for i=2,4 do
			mode_overlays[i] = mode_overlays_from_ini(ini, ini_key, i)
			mode_flag_overlays[i] = mode_flag_overlays_from_ini(ini, ini_key, i)
		end
		last_load_time = mq.gettime()

		self.RefreshFuncs()
	end

	return self
end


--
-- Cast Queue
--

function CastQueueConfig(state, ini)
	local self = GenericConfig(state, ini, 'CastQueue')
	self.__type__ = 'CastQueueConfig'

	local function print()
		return self._value('Print', false)
	end

	local function print_timer()
		return tonumber(self._value('PrintTimer', '10'))
	end

	self.RefreshFuncs = function()
		self.Print = memoized1(print)
		self.PrintTimer = memoized1(print_timer)
	end

	self.Calculate()

	return self
end


--
-- Autosit
--

function AutoSitConfig(state, ini)
	local self = GenericConfig(state, ini, 'AutoSit')
	self.__type__ = 'AutoSitConfig'

	local function enabled()
		return self._value('Enabled', false)
	end
	local function min_hps()
		return self._value('MinHPs', 95)
	end
	local function min_mana()
		return self._value('MinMana', 95)
	end
	local function override_on_move()
		return self._value('OverrideOnMove', false)
	end
	local function override_seconds()
		return self._value('OverrideSeconds', 10)
	end
	self.RefreshFuncs = function()
		self.Enabled = memoized1(enabled)
		self.MinHPs = memoized1(min_hps)
		self.MinMana = memoized1(min_mana)
		self.OverrideOnMove = memoized1(override_on_move)
		self.OverrideSeconds = memoized1(override_seconds)
	end

	self.Calculate()

	return self
end


--
-- Buff
--

function BuffConfig(state, ini)
	local self = GenericConfig(state, ini, 'Buff')
	self.__type__ = 'BuffConfig'

	self.RefreshFuncs = function()
		self.Enabled = memoized1(function()
			return self._value('Enabled', false)
		end)

		self.MinMana = memoized1(function()
			return self._value('MinMana', 45)
		end)

		self.Backoff = memoized1(function()
			return self._value('Backoff', true)
		end)

		self.BackoffTimer = memoized1(function()
			return self._value('BackoffTimer', 300) * 1000
		end)

		self.PackageByName = memoized(function(name)
			return self._csv_value(name)
		end)
	end

	self.Calculate()

	return self
end


--
-- CombatBuff
--

function CombatBuffConfig(state, ini)
	local self = GenericConfig(state, ini, 'CombatBuff')
	self.__type__ = 'CombatBuffConfig'

	self.RefreshFuncs = function()		
		self.Enabled = memoized1(function()
			return self._value('Enabled', false)
		end)

		self.MinMana = memoized1(function()
			return self._value('MinMana', 45)
		end)

		self.Backoff = memoized1(function()
			return self._value('Backoff', true)
		end)

		self.BackoffTimer = memoized1(function()
			return self._value('BackoffTimer', 300) * 1000
		end)

		self.PackageByName = memoized(function(name)
			return self._csv_value(name)
		end)
	end

	self.Calculate()

	return self
end


--
-- Crowd Control
--

function CrowdControlConfig(state, ini)
	local self = GenericConfig(state, ini, 'CrowdControl')
	self.__type__ = 'CrowdControlConfig'

	self.RefreshFuncs = function()
		self.Enabled = memoized1(function()
			return self._value('Enabled', false)
		end)

		self.MinMana = memoized1(function()
			return self._value('MinMana', 10)
		end)

		self.IAmPrimary = memoized1(function()
			return self._value('IAmPrimary', false)
		end)

		self.Spell = memoized1(function()
			return self._value('Spell', '')
		end)
	end

	self.Calculate()

	return self
end


--
-- Debuff
--

function DebuffConfig(state, ini)
	local self = GenericConfig(state, ini, 'Debuff')
	self.__type__ = 'DebuffConfig'

	self.RefreshFuncs = function()
		self.Enabled = memoized1(function()
			return self._value('Enabled', false)
		end)

		self.MinMana = memoized1(function()
			return self._value('MinMana', 45)
		end)

		self.MinTargetHpPct = memoized1(function()
			return self._value('MinTargetHpPct', 65)
		end)

		self.AtTargetHpPcts = memoized1(function()
			local csv = self._csv_value('Pcts')
			local pcts = {}
			for i,s in ipairs(csv) do
				local parts = str.Split(s, ':')
				pcts[tonumber(parts[2])] = parts[1]
			end
			return pcts
		end)
	end

	self.Calculate()

	return self
end


--
-- Dot
--

function DotConfig(state, ini)
	local self = GenericConfig(state, ini, 'Dot')
	self.__type__ = 'DotConfig'

	self.RefreshFuncs = function()
		self.Enabled = memoized1(function()
			return self._value('Enabled', false)
		end)

		self.MinMana = memoized1(function()
			return self._value('MinMana', 50)
		end)

		self.MinTargetHpPct = memoized1(function()
			return self._value('MinTargetHpPct', 65)
		end)

		self.AtTargetHpPcts = memoized1(function()
			local csv = self._csv_value('Pcts')
			local pcts = {}
			for i,s in ipairs(csv) do
				local parts = str.Split(s, ':')
				pcts[tonumber(parts[2])] = parts[1]
			end
			return pcts
		end)
	end

	self.Calculate()

	return self
end


--
-- Heal
--

function HealConfig(state, ini)
	local self = GenericConfig(state, ini, 'Heal')
	self.__type__ = 'HealConfig'

	local function at_hp_pct(type)
		local parts = str.Split(self._value(type, ''), ':')
		if #parts == 2 then
			return { pct = tonumber(parts[2]), key = parts[1] }
		else
			return { pct = 0, key = '' }
		end
	end

	local function enabled()
		return self._value('Enabled', false)
	end

	local function min_mana()
		return self._value('MinMana', 0)
	end

	local function group_at_hp_pct()
		return at_hp_pct('Group')
	end

	local function tank_at_hp_pct()
		return at_hp_pct('Tank')
	end

	local function melee_at_hp_pct()
		return at_hp_pct('Melee')
	end

	local function caster_at_hp_pct()
		return at_hp_pct('Caster')
	end

	local function pet_at_hp_pct()
		return at_hp_pct('Pet')
	end

	local function self_at_hp_pct()
		return at_hp_pct('Self')
	end

	local function selfpet_at_hp_pct()
		return at_hp_pct('Selfpet')
	end

	self.RefreshFuncs = function()
		self.Enabled = memoized1(enabled)
		self.MinMana = memoized1(min_mana)
		self.GroupAtHpPct = memoized1(group_at_hp_pct)
		self.TankAtHpPct = memoized1(tank_at_hp_pct)
		self.MeleeAtHpPct = memoized1(melee_at_hp_pct)
		self.CasterAtHpPct = memoized1(caster_at_hp_pct)
		self.PetAtHpPct = memoized1(pet_at_hp_pct)
		self.SelfAtHpPct = memoized1(self_at_hp_pct)
		self.SelfpetAtHpPct = memoized1(selfpet_at_hp_pct)
	end

	self.Calculate()

	return self
end


--
-- Melee
--

function MeleeConfig(state, ini)
	local self = GenericConfig(state, ini, 'Melee')
	self.__type__ = 'MeleeConfig'

	local function at_hp_pct(type)
		local parts = str.Split(self._value(type, ''), ':')
		if #parts == 2 then
			return tonumber(parts[2]), parts[1]
		else
			return 0, ''
		end
	end

	self.RefreshFuncs = function()
		self.Enabled = memoized1(function()
			return self._value('Enabled', false)
		end)

		self.EngageTargetHPs = memoized1(function()
			return self._value('EngageTargetHPs', 95)
		end)

		self.EngageTargetDistance = memoized1(function()
			return self._value('EngageTargetDistance', 75)
		end)
	end

	self.Calculate()

	return self
end


--
-- DD
--

function DdConfig(state, ini)
	local self = GenericConfig(state, ini, 'DD')
	self.__type__ = 'DdConfig'

	self.RefreshFuncs = function()
		self.Enabled = memoized1(function()
			return self._value('Enabled', false)
		end)

		self.MinMana = memoized1(function()
			return self._value('MinMana', 50)
		end)

		self.MinTargetHpPct = memoized1(function()
			return self._value('MinTargetHpPct', 0)
		end)

		self.AtTargetHpPcts = memoized1(function()
			local csv = self._csv_value('Pcts')
			local pcts = {}
			for i,s in ipairs(csv) do
				local parts = str.Split(s, ':')
				pcts[tonumber(parts[2])] = parts[1]
			end
			return pcts
		end)
	end

	self.Calculate()

	return self
end


--
-- Pet
--

function PetConfig(state, ini)
	local self = GenericConfig(state, ini, 'Pet')
	self.__type__ = 'PetConfig'

	self.RefreshFuncs = function()
		self.AutoCast = memoized1(function()
			return self._value('AutoCast', false)
		end)

		self.AutoAttack = memoized1(function()
			return self._value('AutoAttack', false)
		end)

		self.Type = memoized1(function()
			return self._value('Type', self.DefaultPetType)
		end)

		self.MinMana = memoized1(function()
			return self._value('MinMana', 50)
		end)

		self.EngageTargetHPs = memoized1(function()
			return self._value('EngageTargetHPs', 95)
		end)

		self.EngageTargetDistance = memoized1(function()
			return self._value('EngageTargetDistance', 75)
		end)
	end

	self.Calculate()

	return self
end


--
-- Twist
--

function TwistConfig(state, ini)
	local self = GenericConfig(state, ini, 'Twist')
	self.__type__ = 'TetherConfig'

	self.RefreshFuncs = function()
		self.Enabled = memoized1(function()
			return self._value('Enabled', false)
		end)

		self.Order = memoized1(function()
			return str.Split(self._value('Order', ''), ',')
		end)

		self.CombatOrder = memoized1(function()
			return str.Split(self._value('CombatOrder', ''), ',')
		end)
	end

	self.Calculate()

	return self
end


--
-- Tether
--

function TetherConfig(state, ini)
	local self = GenericConfig(state, ini, 'Tether')
	self.__type__ = 'TetherConfig'

	self.RefreshFuncs = function()
		self.Mode = memoized1(function()
			return self._value('Mode', 'ACTIVE')
		end)

		self.ModeIsActive = memoized1(function()
			return self.Mode():lower() == 'active'
		end)

		self.ModeIsPassive = memoized1(function()
			return self.Mode():lower() == 'passive'
		end)

		self.CampMaxDistance = memoized1(function()
			return self._value('CampMaxDistance', 40)
		end)

		self.FollowMaxDistance = memoized1(function()
			return self._value('FollowMaxDistance', 15)
		end)

		self.ReturnTimer = memoized1(function()
			return self._value('ReturnTimer', 5)
		end)
	end

	self.Calculate()

	return self
end


--
-- TeamEvents
--

function TeamEventsConfig(state, ini)
	local self = GenericConfig(state, ini, 'TeamEvents')
	self.__type__ = 'TeamEventsConfig'

	self.RefreshFuncs = function()
		self.OnPullStart = memoized1(function()
			return self._value('OnPullStart', '')
		end)

		self.OnPullEnd = memoized1(function()
			return self._value('OnPullEnd', '')
		end)

		self.OnPreEngage = memoized1(function()
			return self._value('OnPreEngage', '')
		end)

		self.OnEngage = memoized1(function()
			return self._value('OnEngage', '')
		end)
	end

	self.Calculate()

	return self
end
