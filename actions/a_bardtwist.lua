local mq = require('mq')
local str = require('str')
local array = require('array')
require('actions.action')


function ActBardTwist(gem_order)
    assert(gem_order ~= nil and #gem_order > 0)

    local self = Action('BardTwist')
    self.__type__ = 'ActBardTwist'

    ---@diagnostic disable-next-line: duplicate-set-field
    self.IsReady = function(state, cfg, ctx)
        return not mq.TLO.Twist.Twisting() and state.LastTwistAt + 2000 < mq.gettime()
	end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.Run = function(state, cfg, ctx)
        mq.cmd('/twist ' .. str.Join(gem_order, ' '))
        state.LastTwistAt = mq.gettime()
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.IsFinished = function(state, cfg, ctx)
        if mq.TLO.Twist.Twisting() then
			local current_songs = array.Mapped(
                str.Split(str.Trim(mq.TLO.Twist.List()), ' '),
                function(e) return tonumber(e) end
            )
            return array.Equal(gem_order, current_songs)
        else
            return false
        end
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.OnInterrupt = function(state, cfg, ctx)
        mq.cmd('/twist clear')
    end

    return self
end
