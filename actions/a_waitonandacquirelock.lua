require('actions.action')

function ActWaitOnAndAcquireLock(
    lock_name,
    process_name,
    release_timeout,
    acquire_timeout
)
    assert(lock_name and lock_name:len() > 0)
    assert(process_name and process_name:len() > 0)
    release_timeout = release_timeout or 2000
    acquire_timeout = acquire_timeout or 1500

    local self = Action('WaitOnAndAcquireLock')
    self.__type__ = 'ActWaitOnAndAcquireLock'

    ---@diagnostic disable-next-line: duplicate-set-field
    self.Run = function(state, cfg, ctx)
        local locked, lock = state.WaitOnAndAcquireLock(lock_name, process_name, release_timeout, acquire_timeout)
        assert(locked, 'Could not lock target')
        ctx.Lock = lock
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.OnInterrupt = function(state, cfg, ctx)
        state.ReleaseLock(lock_name, process_name)
    end

    return self
end
