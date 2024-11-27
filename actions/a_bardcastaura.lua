local mq = require('mq')
local co = require('co')
local mychar = require('mychar')
require('actions.action')


function ActBardCastAura(gem)
    gem = gem or 'gem5'
    local gem_number = tonumber(gem:sub(4,4)) or 5

    local self = Action('BardCastAura')
    self.__type__ = 'ActBardCastAura'

    ---@diagnostic disable-next-line: duplicate-set-field
    self.IsReady = function(state, cfg, ctx)
        return mq.TLO.Me.GemTimer(gem_number).TotalSeconds() == 0
	end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.Run = function(state, cfg, ctx)
        mq.cmd('/cast ' .. gem_number)
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.IsFinished = function(state, cfg, ctx)
        ---@diagnostic disable-next-line: undefined-field
        local status = mq.TLO.Cast.Status()
        return status == 'I'
	end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.OnInterrupt = function(state, cfg, ctx)
        mq.cmd('/interrupt')
    end

    return self
end
