local mq = require('mq')
local mychar = require('mychar')
local spells = require('spells')
require('actions.a_castmessage')
require('actions.a_bardcastaura')
require('actions.a_markbardcastactive')
require('actions.a_markbardcastinactive')
require('actions.a_cleartwist')
require('actions.a_memorize')


function ScpBardCastAura(
    spell_name,
    preferred_gem,
    timeout,
    priority
)
    assert(spell_name and spell_name:len() > 0, 'Blank spell_name')
    preferred_gem = preferred_gem or 'gem5'
    timeout = timeout or 10000

    local queue = {}
    table.insert(queue, ActMarkBardCastActive())
    table.insert(queue, ActCastMessage(spell_name, 0))
    table.insert(queue, ActClearTwist())
    table.insert(queue, ActMemorize(spell_name, preferred_gem))
    table.insert(queue, ActBardCastAura(preferred_gem))
    table.insert(queue, ActMarkBardCastInactive())

    local self = Script(
        'cast',
        'cast ' .. spells.HumanString1(spell_name, 0),
        queue,
        timeout,
        priority,
        true
    )

    self._spell_name = spell_name

    ---@diagnostic disable-next-line: duplicate-set-field
    self.IsSame = function(script)
        return script ~= nil and 'cast' == script.Type and spell_name == script._spell_name
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.IsReady = function(state, cfg, ctx)
        return not mychar.IAmInvisible()
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.IsFinished = function(state, cfg, ctx)
        return not mychar.Casting()
    end

    return self
end
