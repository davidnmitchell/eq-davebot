local mq = require('mq')
local mychar = require('mychar')
require('actions.script')
require('actions.action')


function ScpNavToCamp(priority, blocking, callback)
    priority = tonumber(priority) or 99
    blocking = blocking or false

    local nav_action = Action('NavToCamp')
    ---@diagnostic disable-next-line: duplicate-set-field
    nav_action.ShouldSkip = function (state, cfg, ctx)
        return state.TetherStatus ~= 'C', 'not camped'
    end
    ---@diagnostic disable-next-line: duplicate-set-field
    nav_action.Run = function(state, cfg, ctx)
        mq.cmd('/nav loc ' .. state.TetherDetail .. ' log=off')
    end
    ---@diagnostic disable-next-line: duplicate-set-field
    nav_action.IsFinished = function(state, cfg, ctx)
        return not mq.TLO.Navigation.Active()
    end

    local self = Script(
        'nav_to_camp',
        {
            nav_action
        },
        nil,
        priority,
        blocking,
        callback
    )
    self.__type__ = 'ScpNavToCamp'

    return self
end
