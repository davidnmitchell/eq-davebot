local mq     = require('mq')
local mychar = require('mychar')
require('actions.s_cast')


function ScpBuff(
    spell_name,
    preferred_gem,
    min_mana_required,
    target_id,
    in_combat,
    priority,
    callback
)
    local self = ScpCast(
        spell_name,
        preferred_gem,
        min_mana_required,
        1,
        target_id,
        0,
        nil,
        priority,
        callback
    )
    self.__type__ = 'ScpBuff'

    local super_ShouldSkip = self.ShouldSkip

    ---@diagnostic disable-next-line: duplicate-set-field
    self.ShouldSkip = function(state, cfg, ctx)
        if not in_combat and mychar.InCombat() then
            return true, 'in combat'
        else
            return super_ShouldSkip(state, cfg, ctx)
        end
    end

    return self
end
