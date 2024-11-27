local mq = require('mq')
require('actions.a_cast')


function ScpCastMez(
    spell,
    preferred_gem,
    min_mana_required,
    target_id,
    priority,
    callback
)
    local spell_name = spell.Name
    assert(spell_name and spell_name:len() > 0, 'Blank spell_name')

    local self = ScpCast(
        spell,
        preferred_gem,
        min_mana_required,
        3,
        target_id,
        1,
        mq.TLO.Spell(spell_name).CastTime.Raw() + 2000,
        priority,
        callback
    )
    self.__type__ = 'ScpCastMez'

    local super_ShouldSkip = self.ShouldSkip

    local function is_mezzed()
        local count = mq.TLO.Spawn(target_id).BuffCount()
        for i = 1, count do
            if mq.TLO.Spawn(target_id).Buff(i).Category() == 'Utility Detrimental' and mq.TLO.Spawn(target_id).Buff(i).Subcategory() == 'Enthrall' then
                return true
            end
        end
        return false
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.ShouldSkip = function(state, cfg, ctx)
        local super_value, msg = super_ShouldSkip(state, cfg, ctx)
        if super_value then return super_value, msg end
        if is_mezzed() then
            return true, 'target is mezzed'
        end
        return false
    end

    return self
end
