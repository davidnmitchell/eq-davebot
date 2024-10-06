mq = require('mq')
local str = require('str')
local spells = require('spells')
require('eqclass')
require('actions.s_cast')


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

local function spell_from_arg(arg)
    local spell = Config:Spells():Spell(arg)
    if spell.Error == nil then
        return spell.Name
    end
    local name = spells.ReferenceSpell(arg)
    if name ~= nil then return name end
    assert(false, 'Could not find spell "' .. arg .. '"')
end

local function parse_line(args)
	local parsed = {
		gem=0,
		unique=false
	}
	for i=1,#args do
        local parts = str.Split(args[i], '|')
		if parts[1] == '-priority' then
			parsed.priority = tonumber(parts[2])
		elseif parts[1] == '-target' then
			parsed.target_id = target_from_arg(parts[2])
		elseif parts[1] == '-gem' then
			parsed.gem = parts[2]
		elseif parts[1] == '-spell' then
			parsed.spell = spell_from_arg(parts[2])
		elseif parts[1] == '-min_mana' then
			parsed.min_mana = tonumber(parts[2])
		elseif parts[1] == '-min_target_hps' then
			parsed.min_target_hps = tonumber(parts[2])
		elseif parts[1] == '-max_tries' then
			parsed.max_tries = tonumber(parts[2])
		elseif parts[1] == '-unique' then
			parsed.unique = parts[2]:lower() == 'true'
		end
	end
	if parsed.gem == 0 then
		parsed.gem = Config:SpellBar():GemBySpellName(parsed.spell)
		if parsed.gem == 0 then
			parsed.gem = Config:SpellBar():FirstOpenGem()
		end
	end
	if tonumber(parsed.gem) then
		parsed.gem = 'gem' .. parsed.gem
	end
	return ScpCast(
		parsed.spell,
		parsed.gem,
		parsed.min_mana,
		parsed.max_tries,
		parsed.target_id,
		parsed.min_target_hps,
		mq.TLO.Spell(parsed.spell).CastTime.Raw(),
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
