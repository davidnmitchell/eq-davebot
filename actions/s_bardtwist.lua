local mq = require('mq')
local mychar = require('mychar')
local spells = require('spells')
require('actions.a_cleartwist')
require('actions.a_bardtwist')


function ScpBardTwist(
    gem_order,
    priority
)
    assert(gem_order and #gem_order > 0, 'No songs in twist')

    -- TODO: Mem songs
    local queue = {}
    table.insert(queue, ActClearTwist())
    table.insert(queue, ActBardTwist(gem_order))

    local self = Script(
        'bardtwist',
        'bardtwist ' .. table.concat(gem_order, ' '),
        queue,
        nil,
        priority,
        true
    )

    self._gem_order = table.concat(gem_order, ' ')

    ---@diagnostic disable-next-line: duplicate-set-field
    self.IsSame = function(script)
        return script ~= nil and 'bardtwist' == script.Type and self._gem_order == script._gem_order
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.IsReady = function(state, cfg, ctx)
        return not mychar.IAmInvisible()
    end

    return self
end
