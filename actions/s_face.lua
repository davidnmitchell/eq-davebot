local mq = require('mq')
require('actions.script')
require('actions.a_waitonandacquirelock')
require('actions.a_target')
require('actions.a_face')
require('actions.a_releaselock')


function ScpFace(target_id, priority, blocking)
    target_id = tonumber(target_id)
    assert(target_id and target_id > 0, 'Invalid target_id')
    priority = tonumber(priority) or 99
    blocking = blocking or false

    local self = Script(
        'Face ' .. (mq.TLO.Spawn(target_id).CleanName() or 'nil'),
        {
            ActWaitOnAndAcquireLock(
                'target',
                'ScpFace',
                2000,
                2000
            ),
            ActTarget(
                target_id
            ),
            ActFace(
                target_id
            ),
            ActReleaseLock(
                'target',
                'ScpFace'
            )
        },
        nil,
        priority,
        blocking
    )
    self.__type__ = 'ScpFace'

    return self
end
