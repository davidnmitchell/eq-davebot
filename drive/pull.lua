local mq = require('mq')
local co = require('co')
local group = require('group')
local spells = require('spells')
local teamevents = require('teamevents')
require('eqclass')

local Config = {}
local MyClass = EQClass:new()

local function shd_pull()
    local snare = spells.FindSpell('Damage Over Time', 'Snare', 'Single')

    mq.TLO.DaveBot.States.EarlyCombatIsActive()
    co.delay(100)

    mq.cmd('/dbt target last mob')
    mq.delay(5000, function()
        return mq.TLO.Spawn(mq.TLO.Target.ID()).Type() == 'NPC'
    end)
    local target_id = mq.TLO.Target.ID()

    local range = mq.TLO.Spell(snare).Range()
    local distance = mq.TLO.Spawn(target_id).Distance()
    if distance > range then
        print('Out of range')
        mq.TLO.DaveBot.States.EarlyCombatIsInactive()
        return
    end

    if not target_id or group.IsGroupMember(target_id) then
        print('Invalid target')
        mq.TLO.DaveBot.States.EarlyCombatIsInactive()
        return
    end

    spells.WipeQueue()

    mq.delay(5000, function() return mq.TLO.Cast.Ready() end)
    if not mq.TLO.Cast.Ready() then
        mq.TLO.DaveBot.States.EarlyCombatIsInactive()
        return
    end

    if mq.TLO.DaveBot.Tether.Status() ~= 'C' then
        print('Camp is not made')
        mq.TLO.DaveBot.States.EarlyCombatIsInactive()
        return
    end

    local mob = mq.TLO.Spawn(target_id).Name()
    teamevents.PullStart(mob)
    spells.QueueSpell(snare, 'gem4', target_id, 'Pulling ' .. mob .. ' with ' .. snare, 0, 0, 1, 40)
    -- TODO Implement TLO where the castqueue tells us the current spell being cast
    co.delay(1000, function() return mq.TLO.Cast.Status() == 'C' end)
    if not mq.TLO.Cast.Status() == 'C' then
        print('Not casting spell for some reason, aborting...')
        mq.TLO.DaveBot.States.EarlyCombatIsInactive()
        spells.WipeQueue()
        return
    end
    co.delay(mq.TLO.Spell(snare).CastTime())
    co.delay(5000, function() return mq.TLO.Cast.Status() == 'I' end)

    local result = mq.TLO.Cast.Result()
    if result == 'CAST_SUCCESS' or result == 'CAST_RESIST' or result == 'CAST_IMMUNE' then
        mq.cmd('/dbtether return')
        co.delay(1000)
        if mq.TLO.Pet() ~= 'NO PET' then
            mq.cmd('/pet back')
        end
        while mq.TLO.MoveTo.Moving() do
            co.delay(50)
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
    Init = function(cfg)
        Config = cfg
    end
}
