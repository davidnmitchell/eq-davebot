local mq = require('mq')
local co = require('co')
require('actions.action')
local spells = require('spells')
local mychar = require('mychar')


function ActBardCast(
    spell_name,
    gem
)
    assert(spell_name and spell_name:len() > 0)
    assert(gem and gem:len() > 0)

    local self = Action('BardCast')

    ---@diagnostic disable-next-line: duplicate-set-field
    self.Run = function(state, cfg, ctx)
        mq.cmd('/cast ' .. gem)
        co.delay(mq.TLO.Spell(spell_name).CastTime.Raw() + 2000, function() return not mychar.Casting() end)
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.OnInterrupt = function(state, cfg, ctx)
        mq.cmd('/interrupt')
    end

    return self
end
