local mq = require('mq')
local co = require('co')
local mychar = require('mychar')
require('actions.action')


function ActCast(
    spell_name,
    preferred_gem,
    max_tries,
    target_id
)
    assert(spell_name and spell_name:len() > 0)
    preferred_gem = preferred_gem or 'gem5'
    max_tries = max_tries or 1
    target_id = target_id or 0

    local self = Action('Cast')
    self.__type__ = 'ActCast'

    ---@diagnostic disable-next-line: duplicate-set-field
    self.IsReady = function(state, cfg, ctx)
        ---@diagnostic disable-next-line: undefined-field
        return mq.TLO.Cast.Ready(spell_name)()
	end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.Run = function(state, cfg, ctx)
        local cmd = '/casting "' .. spell_name .. '" ' .. preferred_gem .. ' -maxtries|' .. max_tries .. ' -invis'
        if target_id > 0 then
            cmd = cmd .. ' -targetid|' .. target_id
        end
        -- print(cmd)
        mq.cmd(cmd)
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
