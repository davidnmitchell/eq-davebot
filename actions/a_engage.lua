local mq = require('mq')
require('actions.action')


function ActEngage(
    target_id
)
    assert(target_id ~= nil and target_id ~= 0)

    local self = Action()

    ---@diagnostic disable-next-line: duplicate-set-field
    self.Run = function(state, cfg, ctx)
        mq.cmd('/stand')
        mq.cmd('/attack on')
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.OnInterrupt = function(state, cfg, ctx)
        mq.cmd('/attack off')
    end

    return self
end
