local mq = require('mq')
local mychar = require('mychar')
local target = require('target')
local spells = require('spells')
require('actions.a_log')
require('actions.a_memorize')
require('actions.a_cast')
require('actions.a_cursortoinventory')


function ScpSummon(
    spell_name,
    item,
    preferred_gem,
    priority,
    callback
)
    assert(spell_name and spell_name:len() > 0, 'Blank spell_name')
    preferred_gem = preferred_gem or 'gem5'

    local queue = {}
    table.insert(queue, ActLog(string.format('\awSummoning \ag%s', item)))
    table.insert(queue, ActMemorize(spell_name, preferred_gem, true))
    table.insert(queue, ActCast(spell_name, preferred_gem, 20))
    table.insert(queue, ActCursorToInventory())

    local self = Script(
        'summon',
        'summon ' .. item,
        queue,
        mq.TLO.Spell(spell_name).CastTime() + 10000,
        priority,
        true,
        callback
    )

    self._spell_name = spell_name

    local function i_have_enough_mana()
        return mq.TLO.Me.CurrentMana() >= mq.TLO.Spell(spell_name).Mana()
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.IsSame = function(script)
        return script ~= nil and 'cast' == script.Type and spell_name == script._spell_name
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.IsReady = function(state, cfg, ctx)
        return mychar.ReadyToCast and i_have_enough_mana() and not mychar.IAmInvisible()
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.IsFinished = function(state, cfg, ctx)
        return not mychar.Casting()
    end

    return self
end
