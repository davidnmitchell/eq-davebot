local mq = require('mq')
require('actions.script')
require('actions.a_waitonandacquirelock')
require('actions.a_engagemessage')
require('actions.a_target')
require('actions.a_face')
require('actions.a_engage')
require('actions.a_releaselock')


function ScpEngage(target_id, priority)
    target_id = tonumber(target_id)
    assert(target_id and target_id > 0, 'Invalid target_id')
    priority = tonumber(priority) or 99

    local self = Script(
        'engage',
        'engage ' .. mq.TLO.Spawn(target_id).CleanName(),
        {
            ActWaitOnAndAcquireLock(
                'target',
                'ScpEngage'
            ),
            ActEngageMessage(target_id),
            ActTarget(target_id),
            ActFace(target_id),
            ActEngage(target_id),
            ActReleaseLock(
                'target',
                'ScpEngage'
            )
        },
        nil,
        priority,
        true
    )

    return self
end
