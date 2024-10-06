require('actions.action')

function ActMarkBardCastInactive()
    local self = Action('MarkBardCastInactive')

    ---@diagnostic disable-next-line: duplicate-set-field
    self.Run = function(state, cfg, ctx)
        state:MarkBardCastInactive()
    end

    return self
end
