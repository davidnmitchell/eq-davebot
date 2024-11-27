local mq = require('mq')
require('actions.script')
require('actions.a_waitonandacquirelock')
require('actions.a_target')
require('actions.a_releaselock')


function ScpTarget(target_id, priority)
    target_id = tonumber(target_id)
    assert(target_id and target_id > 0, 'Invalid target_id')
    priority = tonumber(priority) or 99

    local self = Script(
        'target ' .. mq.TLO.Spawn(target_id).CleanName(),
        {
            ActWaitOnAndAcquireLock(
                'target',
                'ScpEngage'
            ),
            ActTarget(target_id),
            ActReleaseLock(
                'target',
                'ScpEngage'
            )
        },
        nil,
        priority,
        true
    )
    self.__type__ = 'ScpTarget'

    return self
end
