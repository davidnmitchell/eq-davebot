local mq = require('mq')
local co = require('co')

function ActTarget(target_id)
    assert(target_id and target_id > 0)

    local self = Action('Target')
    self.__type__ = 'ActTarget'

    ---@diagnostic disable-next-line: duplicate-set-field
    self.Run = function(state, cfg, ctx)
        assert(
            assert(ctx.Lock, 'No lock in script context').ReleaseAt > mq.gettime() + 550,
            'Target Lock is not active or not locked for enough time'
        )
        mq.TLO.Spawn(target_id).DoTarget()
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.IsFinished = function(state, cfg, ctx)
        return mq.TLO.Target.ID() == target_id
    end

    return self
end
