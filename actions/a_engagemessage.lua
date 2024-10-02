local mq = require('mq')
require('actions.action')


function ActEngageMessage(target_id)
    assert(target_id ~= nil and target_id ~= 0)

    local self = Action()

    ---@diagnostic disable-next-line: duplicate-set-field
    self.Run = function(state, cfg, ctx)
        self.announce('Engaging ' .. mq.TLO.Spawn(target_id).CleanName())
    end

    return self
end
