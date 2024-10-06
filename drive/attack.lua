local mq = require('mq')
local co = require('co')
local group = require('group')
local teamevents = require('teamevents')
require('eqclass')


local actionqueue = {}

local MyClass = EQClass:new()
local State = {}
local Config = {}

local EngageDistance = 80
local Timeout = 35


local function in_xtargets(target_id)
    local i = 1
    local cur_id = mq.TLO.Me.XTarget(i).ID()
    while cur_id ~= nil do
        if cur_id == target_id then
            return true
        end
        i = i + 1
        cur_id = mq.TLO.Me.XTarget(i).ID()
    end
    return false
end

local function target(target_id)
    local locked, lock = State:WaitOnAndAcquireLock('target', 'attack', 2000, 2000)
    if not locked then
        print('Could not target')
        return
    end

    mq.TLO.Spawn(target_id).DoTarget()
    --mq.cmd('/target id ' .. target_id)

    State:ReleaseLock('target', 'attack')
end

local function tank_attack()
    ---@diagnostic disable-next-line: undefined-field
    local target_id = tonumber(mq.TLO.Me.GroupAssistTarget.ID())

    State:MarkEarlyCombatActive()

    if target_id == nil or target_id == 0 then
        target_id = tonumber(mq.TLO.Me.XTarget(1).ID())
        if target_id == nil then return end

        target(target_id)

        co.delay(100)
    end

    if target_id == mq.TLO.Me.ID() then
        print('Can\'t attack yourself')
        State:MarkEarlyCombatInactive()
        return
    end
    if group.IsGroupMember(target_id) then
        print('Can\'t attack a group member')
        State:MarkEarlyCombatInactive()
        return
    end

    if not in_xtargets(target_id) then
        local first = mq.TLO.Me.XTarget(1).ID()
        if first ~= nil and first ~= 0 then
            target_id = first
            target(target_id)
        end
    end

	local mob = mq.TLO.Spawn(target_id).Name()
	teamevents.PreEngage(mob)
	mq.cmd('/face')

    co.delay(
        Timeout * 1000,
        function()
            mq.cmd('/face')
            return mq.TLO.Target.Distance() <= EngageDistance
        end
    )
    if mq.TLO.Target.Distance() <= EngageDistance then
        teamevents.Engage(mob)
        while not mq.TLO.Me.Combat() do
            mq.cmd('/attack on')
            co.delay(50)
        end
    else
        print('Auto-engage timeout, you will need to manually engage')
    end

end

return {
    Run = function(...)
        if MyClass.Name == 'Shadow Knight' then
            tank_attack()
        elseif MyClass.Name == 'Paladin' then
            tank_attack()
        end
    end,
    Init = function(state, cfg, aq)
        State = state
        Config = cfg
        actionqueue = aq
    end
}
