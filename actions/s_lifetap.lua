local mq = require('mq')
require('actions.s_cast')


function ScpLifetap(
    spell_name,
    preferred_gem,
    min_mana_required,
    max_tries,
    target_id,
    skip_if_target_hp_below,
    timeout,
    priority,
    callback
)
    local self = ScpCast(
        spell_name,
        preferred_gem,
        min_mana_required,
        max_tries,
        target_id,
        skip_if_target_hp_below,
        timeout,
        priority,
        callback
    )
    local super_ShouldSkip = self.ShouldSkip

    ---@diagnostic disable-next-line: duplicate-set-field
    self.ShouldSkip = function(state, cfg, ctx)
        if mq.TLO.Target.ID() ~= target_id then
            return true, 'target has switched'
        else
            return super_ShouldSkip(state, cfg, ctx)
        end
    end

    return self
end
