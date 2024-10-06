require('actions.action')


function ActLog(message)
    assert(message and message:len() > 0)

    local self = Action('Log')

    ---@diagnostic disable-next-line: duplicate-set-field
    self.Run = function(state, cfg, ctx)
        self.log(message)
    end

    return self
end
