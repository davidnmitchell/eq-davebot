local mq = require('mq')
require('actions.a_cast')


function ScpCastHeal(
    spell,
    preferred_gem,
    min_mana_required,
    target_id,
    pct_threshold,
    priority,
    callback
)
    local self = ScpCast(
        spell,
        preferred_gem,
        min_mana_required,
        3,
        target_id,
        0,
        nil,
        priority,
        callback
    )
    self.__type__ = 'ScpCastHeal'

    local super_ShouldSkip = self.ShouldSkip

    ---@diagnostic disable-next-line: duplicate-set-field
    self.ShouldSkip = function(state, cfg, ctx)
        local super_value, msg = super_ShouldSkip(state, cfg, ctx)
        if super_value then return super_value, msg end
        if mq.TLO.Spawn(target_id).PctHPs() > pct_threshold then
            return true, 'target has enough health already'
        end
        return false
    end

    return self
end
