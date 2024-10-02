local mq = require('mq')
local co = require('co')


function ActFace(target_id)
    assert(target_id and target_id > 0)

    local self = Action()

    ---@diagnostic disable-next-line: duplicate-set-field
    self.Run = function(state, cfg, ctx)
        mq.cmd('/face id ' .. target_id)
        co.delay(50)
    end

    return self
end
