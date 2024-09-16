local mq = require('mq')
local co = require('co')
local group = require('group')
local teamevents = require('teamevents')
require('eqclass')

local MyClass = EQClass:new()
local EngageDistance = 80

local function tank_attack()
    local target = tonumber(mq.TLO.Me.GroupAssistTarget.ID())

    if target == nil or target == 0 then
        target = tonumber(mq.TLO.Me.XTarget(1).ID())
        if target == nil then return end
        mq.cmd('/target id ' .. target)
        co.delay(100)
    end

    if target == mq.TLO.Me.ID() then
        print('Can\'t attack yourself')
        return
    end
    if group.IsGroupMember(target) then
        print('Can\'t attack a group member')
        return
    end

	local mob = mq.TLO.Spawn(target).Name()
	teamevents.PreEngage(mob)
	mq.cmd('/face')

    co.delay(
        30000,
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
        end
    end
}
