local mq = require('mq')
local co = require('co')
local group = require('group')
local spells = require('spells')
local teamevents = require('teamevents')
require('eqclass')
require('actions.s_cast')


local actionqueue = {}

local MyClass = EQClass:new()
local State = {}
local Config = {}


local function shd_pull()
    local snare = spells.FindSpell('Damage Over Time', 'Snare', 'Single')

    State.MarkEarlyCombatActive()
    co.delay(100)

    local last_npc = State.LastTargetOf(
        function(id)
            return mq.TLO.Spawn(id).Type() == 'NPC'
        end
    )

    if last_npc <= 0 then
        print('Could not find npc in target history to pull')
        State.MarkEarlyCombatInactive()
        return
    end

    print('Pulling ' .. mq.TLO.Spawn(last_npc).CleanName())

    local locked, lock = State.WaitOnAndAcquireLock('target', 'pull', 2000, 2000)
    if not locked then
        print('Could not target')
        State.MarkEarlyCombatInactive()
        return
    end

    mq.TLO.Spawn(last_npc).DoTarget()
    --mq.cmd('/target id ' .. last_npc)
    co.delay(5000, function() return mq.TLO.Target.ID() == last_npc end)

    local target_id = mq.TLO.Target.ID()

    local range = mq.TLO.Spell(snare).Range()
    local distance = mq.TLO.Spawn(target_id).Distance()
    if distance > range then
        print('Out of range')
        State.MarkEarlyCombatInactive()
        return
    end

    if not target_id or group.IsGroupMember(target_id) then
        print('Invalid target')
        State.MarkEarlyCombatInactive()
        return
    end

    State.ReleaseLock('target', 'pull')

    actionqueue.Wipe()

    ---@diagnostic disable-next-line: undefined-field
    co.delay(5000, function() return mq.TLO.Cast.Ready() end)
    ---@diagnostic disable-next-line: undefined-field
    if not mq.TLO.Cast.Ready() then
        print('Not ready to cast spell')
        State.MarkEarlyCombatInactive()
        return
    end

    if State.TetherStatus ~= 'C' then
        print('Camp is not made')
        State.MarkEarlyCombatInactive()
        return
    end

    teamevents.PullStart(mq.TLO.Spawn(target_id).Name())
    local done_casting = false
    actionqueue.Add(
        ScpCast(
            snare,
            'gem' .. Config:SpellBar():GemBySpellName(snare),
            0,
            1,
            target_id,
            0,
            nil,
            41,
            function() done_casting = true end
        )
    )
    ---@diagnostic disable-next-line: undefined-field
    co.delay(5000, function() return mq.TLO.Cast.Status() == 'C' end)
    ---@diagnostic disable-next-line: undefined-field
    if mq.TLO.Cast.Status() ~= 'C' then
        print('Not casting spell for some reason, aborting...')
        State.MarkEarlyCombatInactive()
        actionqueue.Wipe()
        return
    end
    co.delay(mq.TLO.Spell(snare).CastTime() + 5000, function() return done_casting end)
    ---@diagnostic disable-next-line: undefined-field
    co.delay(5000, function() return mq.TLO.Cast.Status() == 'I' end)

    ---@diagnostic disable-next-line: undefined-field
    local result = mq.TLO.Cast.Result()
    if result == 'CAST_SUCCESS' or result == 'CAST_RESIST' or result == 'CAST_IMMUNE' then
        local done_returning = false
        actionqueue.Add(
            ScpNavToCamp(
                42,
                false,
                function() done_returning = true end
            )
        )
        co.delay(1000)
        if mq.TLO.Pet() ~= 'NO PET' then
            mq.cmd('/pet back')
        end
        co.delay(60000, function() return done_returning end)
        if mq.TLO.MoveTo.Moving() then
            print('Nav took longer than expected')
            State.MarkEarlyCombatInactive()
            return
        end
        -- TODO make this exit-able
        teamevents.PullEnd()
        mq.cmd('/drive attack')
    else
        print(result)
    end
end

return {
    Run = function(...)
        if MyClass.Name == 'Shadow Knight' then
            shd_pull()
        end
    end,
    Init = function(state, cfg, aq)
        State = state
        Config = cfg
        actionqueue = aq
    end
}
