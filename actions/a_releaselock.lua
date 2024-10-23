require('actions.action')

function ActReleaseLock(lock_name, process_name)
    assert(lock_name)
    assert(process_name)

    local self = Action('ReleaseLock', false)

    ---@diagnostic disable-next-line: duplicate-set-field
    self.Run = function(state, cfg, ctx)
        state.ReleaseLock(lock_name, process_name)
    end

    return self
end
