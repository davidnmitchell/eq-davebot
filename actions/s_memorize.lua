local mq = require('mq')
local mychar = require('mychar')
local target = require('target')
local spells = require('spells')
require('actions.a_markbardcastactive')
require('actions.a_markbardcastinactive')
require('actions.a_cleartwist')
require('actions.a_clearwronggem')
require('actions.a_memorize')


function ScpMemorize(
    spell_name,
    preferred_gem,
    wait_for_ready,
    priority
)
    assert(spell_name and spell_name:len() > 0, 'Blank spell_name')
    preferred_gem = preferred_gem or 'gem5'
    wait_for_ready = wait_for_ready or true
    local timeout = mq.TLO.Spell(spell_name).RecoveryTime.Raw() + 1500

    local queue = {}
    if mq.TLO.Me.Class.Name() == 'Bard' then
        table.insert(queue, ActMarkBardCastActive())
        table.insert(queue, ActClearTwist())
        table.insert(queue, ActClearWrongGem(spell_name, preferred_gem))
        table.insert(queue, ActMemorize(spell_name, preferred_gem, wait_for_ready))
        table.insert(queue, ActMarkBardCastInactive())
    else
        table.insert(queue, ActClearWrongGem(spell_name, preferred_gem))
        table.insert(queue, ActMemorize(spell_name, preferred_gem, wait_for_ready))
    end

    local self = Script(
        'memorize ' .. spell_name,
        queue,
        timeout,
        priority,
        true
    )
    self.__type__ = 'ScpMemorize'

    self._spell_name = spell_name

    ---@diagnostic disable-next-line: duplicate-set-field
    self.IsSame = function(script)
        return script ~= nil and self.__type__ == script.__type__ and spell_name == script._spell_name
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.IsFinished = function(state, cfg, ctx)
        return mychar.ReadyToCast()
    end

    return self
end
