local mq = require('mq')
require('actions.action')


function ActPetEngage(
    target_id
)
    assert(target_id ~= nil and target_id ~= 0)

    local self = Action('PetEngage')

    ---@diagnostic disable-next-line: duplicate-set-field
    self.Run = function(state, cfg, ctx)
        mq.cmd('/pet attack')
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.OnInterrupt = function(state, cfg, ctx)
        mq.cmd('/pet back')
    end

    return self
end
