local mq = require('mq')
local mychar = require('mychar')
local target = require('target')
local spells = require('spells')
require('actions.a_castmessage')
require('actions.s_face')
require('actions.a_cast')
require('actions.a_bardcast')
require('actions.a_markbardcastactive')
require('actions.a_markbardcastinactive')
require('actions.a_cleartwist')
require('actions.a_memorize')


function ScpCast(
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
    assert(spell_name and spell_name:len() > 0, 'Blank spell_name')
    preferred_gem = preferred_gem or 'gem5'
    min_mana_required = min_mana_required or 0
    target_id = target_id or 0
    skip_if_target_hp_below = skip_if_target_hp_below or 0
    timeout = timeout or ((mq.TLO.Spell(spell_name).CastTime.Raw() or 5000) + (1000 * max_tries) + 1000)

    local queue = {}
    if mq.TLO.Me.Class.Name() == 'Bard' then
        table.insert(queue, ActMarkBardCastActive())
        table.insert(queue, ActCastMessage(spell_name, target_id))
        table.insert(queue, ActClearTwist())
        table.insert(queue, ActMemorize(spell_name, preferred_gem, true))
        if target_id > 0 and target_id ~= mq.TLO.Me.ID() then table.insert(queue, ScpFace(target_id, nil, false)) end
        table.insert(queue, ActCast(spell_name, preferred_gem, max_tries, target_id))
        table.insert(queue, ActMarkBardCastInactive())
    else
        table.insert(queue, ActCastMessage(spell_name, target_id))
        table.insert(queue, ActMemorize(spell_name, preferred_gem, true))
        if target_id > 0 and target_id ~= mq.TLO.Me.ID() then table.insert(queue, ScpFace(target_id, nil, false)) end
        table.insert(queue, ActCast(spell_name, preferred_gem, max_tries, target_id))
    end

    local self = Script(
        'cast',
        'cast ' .. spells.HumanString1(spell_name, target_id),
        queue,
        timeout,
        priority,
        true,
        callback
    )

    self._spell_name = spell_name
    self._target_id = target_id

    local function is_immune(state, cfg)
        for i, scp_cast in ipairs(state.Immunes) do
            if self.IsSame(scp_cast) then return true end
        end
        return false
    end

    local function target_hps_are_too_low()
        local target_hp_pct = mq.TLO.Spawn(self._target_id).PctHPs() or -1
        return target_hp_pct < skip_if_target_hp_below
    end

    local function i_have_enough_mana()
        return mq.TLO.Me.PctMana() >= min_mana_required
    end

    local function has_target()
        return target_id > 0
    end

    local function in_range()
        local range = mq.TLO.Spell(spell_name).Range() or 200
        local distance = mq.TLO.Spawn(target_id).Distance() or 0

        return range == 0 or distance <= range
    end

    local function line_of_sight()
        return mq.TLO.Spawn(target_id).LineOfSight() or false
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.IsSame = function(script)
        return script ~= nil and 'cast' == script.Type and spell_name == script._spell_name and target_id == script._target_id
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.ShouldSkip = function(state, cfg, ctx)
        if has_target() and not target.IsAlive(target_id) then
            return true, 'target is dead'
        elseif is_immune(state, cfg) then
            return true, 'target is immune'
        elseif has_target() and target_hps_are_too_low() then
            return true, 'target hit points are too low'
        end
        return false
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.IsReady = function(state, cfg, ctx)
        local ready_to_cast = false
        if mq.TLO.Me.Class.Name() == 'Bard' then
            ready_to_cast = true
        else
            ready_to_cast = mychar.ReadyToCast()
        end
        return ready_to_cast and i_have_enough_mana() and (not has_target() or (in_range() and line_of_sight())) and not mychar.IAmInvisible()
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.IsFinished = function(state, cfg, ctx)
        return not mychar.Casting()
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.PostAction = function(state, cfg, ctx)
        ---@diagnostic disable-next-line: undefined-field
        local result = mq.TLO.Cast.Result()
        if result ~= nil and result == 'CAST_IMMUNE' then
            table.insert(state.Immunes, self)
        end
    end

    return self
end
