local mq = require('mq')
local co = require('co')


function ActFace(target_id)
    assert(target_id and target_id > 0)

    local self = Action('Face')
    self.__type__ = 'ActFace'

    ---@diagnostic disable-next-line: duplicate-set-field
    self.Run = function(state, cfg, ctx)
        mq.cmd('/face id ' .. target_id)
    end

    return self
end
