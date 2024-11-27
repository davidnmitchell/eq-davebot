require('actions.action')

function ActMarkBardCastInactive()
    local self = Action('MarkBardCastInactive')
    self.__type__ = 'ActMarkBardCastInactive'

    ---@diagnostic disable-next-line: duplicate-set-field
    self.Run = function(state, cfg, ctx)
        state.MarkBardCastInactive()
    end

    return self
end
