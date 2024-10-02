local mq = require('mq')
local mychar = require('mychar')
require('actions.script')
require('actions.action')


function ScpSit(priority, blocking)
    priority = tonumber(priority) or 99
    blocking = blocking or false

    local sit_action = Action()
    ---@diagnostic disable-next-line: duplicate-set-field
    sit_action.ShouldSkip = function(state, cfg, ctx)
        if not mychar.ReadyToCast() then
            return true, 'not ready'
        end
        if mychar.InCombat() then
            return true, 'in combat'
        end
        if not mychar.CanRest() then
            return true, 'cannot rest'
        end
        if state.NoSitUntil > mq.gettime() then
            return true, 'overridden'
        end
        return false
    end
    ---@diagnostic disable-next-line: duplicate-set-field
    sit_action.Run = function(state, cfg, ctx)
        mq.cmd('/sit')
        state.Sitting = true
    end
    ---@diagnostic disable-next-line: duplicate-set-field
    sit_action.IsFinished = function(state, cfg, ctx)
        return mq.TLO.Me.Sitting()
    end

    local self = Script(
        'sit',
        'sit',
        {
            sit_action
        },
        priority,
        blocking
    )

    return self
end
