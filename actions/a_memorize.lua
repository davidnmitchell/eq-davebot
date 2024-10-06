local mq = require('mq')
local co = require('co')
require('actions.action')
local mychar = require('mychar')


function ActMemorize(
    spell_name,
    preferred_gem,
    wait_for_ready
)
    assert(spell_name and spell_name:len() > 0)
    preferred_gem = preferred_gem or 'gem5'
    wait_for_ready = wait_for_ready or true
    local gem_number = tonumber(preferred_gem:sub(4,4)) or 5

    local ready_timeout = 10000
    local finish_timeout = 10000
    if wait_for_ready then
        finish_timeout = mq.TLO.Spell(spell_name).RecastTime() + 10000
    end
    local self = Action('Memorize', true, ready_timeout, finish_timeout)

    ---@diagnostic disable-next-line: duplicate-set-field
    self.ShouldSkip = function(state, cfg, ctx)
        return mq.TLO.Me.Gem(gem_number).Name() == spell_name, 'already memorized'
	end

    ---@diagnostic disable-next-line: duplicate-set-field
	self.IsReady = function(state, cfg, ctx)
        return mychar.ReadyToCast()
	end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.Run = function(state, cfg, ctx)
        self.log('Memorizing ' .. spell_name .. ' in slot ' .. gem_number)
        mq.cmd('/memorize "' .. spell_name .. '" gem' .. gem_number)
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.IsFinished = function(state, cfg, ctx)
        if wait_for_ready then
            ---@diagnostic disable-next-line: undefined-field
            return mq.TLO.Cast.Ready(gem_number)() and mq.TLO.Cast.Status() == 'I'
        end
        ---@diagnostic disable-next-line: undefined-field
        return mq.TLO.Cast.Status() == 'I'
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.OnInterrupt = function(state, cfg, ctx)
        mq.cmd('/interrupt')
    end

    return self
end
