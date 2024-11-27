mq = require('mq')
local str = require('str')
local spells = require('spells')
require('eqclass')
require('actions.s_cast')
local array  = require('array')
local common = require('common')


local actionqueue = {}

local MyClass = EQClass:new()
local State = {}
local Config = {}


local function target_from_arg(arg)
    local num = tonumber(arg)
    if num ~= nil then return num end

    local spawn = mq.TLO.Spawn(arg).ID()
    if spawn ~= nil and spawn ~= 0 then return spawn end

    local tlo = assert(load('return mq.TLO.' .. arg .. '()'))()
    num = tonumber(tlo)
    if num ~= nil then return num end

    spawn = mq.TLO.Spawn(tlo).ID()
    if spawn ~= nil then return spawn end

    assert(false, 'Could not find target "' .. arg .. '"')
end

local function castable_from_arg(arg)
    local castable = Config.Spells.Spell(arg)
    if castable.Error ~= nil then
		assert(false, castable.Error)
	end
	return castable
end

local function split_key_value(kv)
	local parts = str.Split(kv, '|')
	return str.Trim(parts[1]), str.Trim(parts[2])
end

local function parse_line(args)
	local parts = array.Filtered(str.Split(table.concat(args, ' '), '-'), function(s) return #s > 0 end)
	local parsed = {
		gem=0,
		unique=false
	}
	for i=1,#parts do
		local key, value = split_key_value(parts[i])
		if key == 'priority' then
			parsed.priority = tonumber(value)
		elseif key == 'target' then
			parsed.target_id = target_from_arg(value)
		elseif key == 'gem' then
			parsed.gem = value
		elseif key == 'spell' then
			parsed.castable = castable_from_arg(value)
		elseif key == 'min_mana' then
			parsed.min_mana = tonumber(value)
		elseif key == 'min_target_hps' then
			parsed.min_target_hps = tonumber(value)
		elseif key == 'max_tries' then
			parsed.max_tries = tonumber(value)
		elseif key == 'unique' then
			parsed.unique = value:lower() == 'true'
		end
	end
	if parsed.gem == 0 then
		if parsed.castable.Type == 'item' then
			parsed.gem = 'item'
		elseif parsed.castable.Type == 'alt' then
			parsed.gem = 'alt'
		elseif parsed.castable.Type == 'spell' then
			local res = Config.SpellBar.GemBySpell(parsed.castable)
			if res.gem < 1 then
				assert(false, res.msg)
			end
			parsed.gem = res.gem
		end
	end
	if tonumber(parsed.gem) then
		parsed.gem = 'gem' .. parsed.gem
	end
	print(parsed.castable.Name .. ':' .. parsed.gem)
	return ScpCast(
		parsed.castable,
		parsed.gem,
		parsed.min_mana,
		parsed.max_tries,
		parsed.target_id,
		parsed.min_target_hps,
		mq.TLO.Spell(parsed.castable).CastTime.Raw(),
		parsed.priority
	), parsed.unique
end


return {
    Run = function(...)
        local args = { ... }
        local action, unique = parse_line(args)
        if unique then
            actionqueue.AddUnique(action)
        else
            actionqueue.Add(action)
        end
    end,
    Init = function(state, cfg, aq)
        State = state
        Config = cfg
        actionqueue = aq
    end
}
