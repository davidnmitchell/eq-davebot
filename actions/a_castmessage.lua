local spells = require('spells')
require('actions.action')


function ActCastMessage(spell_name, target_id)
    assert(spell_name and spell_name:len() > 0)
    target_id = target_id or 0

    local self = Action('CastMessage')
    self.__type__ = 'ActCastMessage'

    ---@diagnostic disable-next-line: duplicate-set-field
    self.Run = function(state, cfg, ctx)
        self.log('Casting ' .. spells.HumanString1(spell_name, target_id))
    end

    return self
end
