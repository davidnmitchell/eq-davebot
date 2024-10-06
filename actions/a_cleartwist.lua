local mq = require('mq')
local co = require('co')
require('actions.action')
local spells = require('spells')


function ActClearTwist()
    local self = Action('ClearTwist')

    ---@diagnostic disable-next-line: duplicate-set-field
    self.Run = function(state, cfg, ctx)
        mq.cmd('/twist clear')
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.IsFinished = function(state, cfg, ctx)
		return not mq.TLO.Twist.Twisting()
	end

    return self
end
