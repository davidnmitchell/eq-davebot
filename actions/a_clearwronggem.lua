local mq = require('mq')
local co = require('co')
local mychar = require('mychar')
require('actions.action')


function ActClearWrongGem(
    spell_name,
    preferred_gem
)
    assert(spell_name and spell_name:len() > 0)
    preferred_gem = preferred_gem or 'gem5'
    local gem_number = tonumber(preferred_gem:sub(4,4)) or 1

    local self = Action('ClearWrongGem')

    ---@diagnostic disable-next-line: duplicate-set-field
    self.ShouldSkip = function(state, cfg, ctx)
        return mq.TLO.Me.Gem(gem_number).Name() == spell_name, ''
	end

    ---@diagnostic disable-next-line: duplicate-set-field
	self.IsReady = function(state, cfg, ctx)
        return mychar.ReadyToCast()
	end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.Run = function(state, cfg, ctx)
        local cmd = '/memspellslot ' .. gem_number ..' 0'
        mq.cmd(cmd)
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.IsFinished = function(state, cfg, ctx)
        return mq.TLO.Me.Gem(gem_number).Name() == nil
	end

    return self
end
