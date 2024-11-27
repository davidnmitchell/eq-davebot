local mq = require('mq')
require('actions.script')
require('actions.a_waitonandacquirelock')
require('actions.a_petengagemessage')
require('actions.a_target')
require('actions.a_face')
require('actions.a_petengage')
require('actions.a_releaselock')


function ScpPetEngage(target_id, priority)
    target_id = tonumber(target_id)
    assert(target_id and target_id > 0, 'Invalid target_id')
    priority = tonumber(priority) or 99

    local self = Script(
        'petengage ' .. mq.TLO.Spawn(target_id).CleanName(),
        {
            ActWaitOnAndAcquireLock(
                'target',
                'ScpPetEngage'
            ),
            ActPetEngageMessage(target_id),
            ActTarget(target_id),
            ActPetEngage(target_id),
            ActReleaseLock(
                'target',
                'ScpPetEngage'
            )
        },
        nil,
        priority,
        true
    )
    self.__type__ = 'ScpPetEngage'

    return self
end
