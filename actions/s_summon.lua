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
    put_in_inventory,
    callback
)
    assert(spell_name and spell_name:len() > 0, 'Blank spell_name')
    preferred_gem = preferred_gem or 'gem5'
    if tonumber(preferred_gem) ~= nil then preferred_gem = 'gem' .. preferred_gem end
    if put_in_inventory == nil then put_in_inventory = true end

    local queue = {}
    table.insert(queue, ActLog(string.format('\awSummoning \ag%s', item)))
    table.insert(queue, ActMemorize(spell_name, preferred_gem, true))
    table.insert(queue, ActCast(spell_name, preferred_gem, 20))
    if put_in_inventory then table.insert(queue, ActCursorToInventory()) end

    local self = Script(
        'summon ' .. item,
        queue,
        mq.TLO.Spell(spell_name).CastTime() + 10000,
        priority,
        true,
        callback
    )
    self.__type__ = 'ScpSummon'

    self._spell_name = spell_name

    local function i_have_enough_mana()
        return mq.TLO.Me.CurrentMana() >= mq.TLO.Spell(spell_name).Mana()
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.IsSame = function(script)
        return script ~= nil and self.__type__ == script.__type__ and spell_name == script._spell_name
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.ShouldSkip = function(state, cfg, ctx)
        return mq.TLO.Cursor.ID() ~= nil
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.IsReady = function(state, cfg, ctx)
        return mychar.ReadyToCast() and i_have_enough_mana() and not mychar.IAmInvisible()
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.IsFinished = function(state, cfg, ctx)
        return not mychar.Casting()
    end

    return self
end
