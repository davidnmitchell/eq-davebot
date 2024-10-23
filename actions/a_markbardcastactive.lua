require('actions.action')

function ActMarkBardCastActive()
    local self = Action('MarkBardCastActive')

    ---@diagnostic disable-next-line: duplicate-set-field
    self.Run = function(state, cfg, ctx)
        state.MarkBardCastActive()
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.OnInterrupt = function(state, cfg, ctx)
        state.MarkBardCastInactive()
    end

    return self
end
