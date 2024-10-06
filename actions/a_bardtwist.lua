local mq = require('mq')
local co = require('co')
local str = require('str')
local mychar = require('mychar')
require('actions.action')


function ActBardTwist(gem_order)
    assert(gem_order ~= nil and #gem_order > 0)

    local self = Action('BardTwist')

    ---@diagnostic disable-next-line: duplicate-set-field
    self.IsReady = function(state, cfg, ctx)
        return not mq.TLO.Twist.Twisting() and state.LastTwistAt + 2000 < mq.gettime()
	end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.Run = function(state, cfg, ctx)
        local cmd = '/twist'
        for i, gem in ipairs(gem_order) do
            cmd = cmd .. ' ' .. gem
        end
        mq.cmd(cmd)
        state.LastTwistAt = mq.gettime()
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.IsFinished = function(state, cfg, ctx)
        if mq.TLO.Twist.Twisting() then
			local current_songs = str.Split(str.Trim(mq.TLO.Twist.List()), ' ')
			if #gem_order ~= #current_songs then
				return false
			else
				for i,v in ipairs(current_songs) do
					local gem = tonumber(v)
					local expected_gem = gem_order[i]
					if gem ~= expected_gem then
						return false
					end
				end
			end
            return true
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
