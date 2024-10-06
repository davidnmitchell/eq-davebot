local mq = require('mq')
require('actions.action')


function ActPetEngageMessage(target_id)
    assert(target_id ~= nil and target_id ~= 0)

    local self = Action('PetEngageMessage')

    ---@diagnostic disable-next-line: duplicate-set-field
    self.ShouldSkip = function(state, cfg, ctx)
        return mq.TLO.Spawn(target_id).CleanName() == nil, ''
    end
    ---@diagnostic disable-next-line: duplicate-set-field
    self.Run = function(state, cfg, ctx)
        self.log('Telling pet to attack')
        self.announce('Pet is engaging ' .. mq.TLO.Spawn(target_id).CleanName())
    end

    return self
end
