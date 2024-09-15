local mq = require('mq')
local co = require('co')
local group = require('group')
local teamevents = require('teamevents')
require('eqclass')

local MyClass = EQClass:new()

local function shd_attack()
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
	co.delay(50)
	while mq.TLO.Target.Distance() > 80 do
		co.delay(50)
		mq.cmd('/face')
	end
	teamevents.Engage(mob)
	mq.cmd('/attack on')

    -- local aggro = spells.FindSpell('Utility Detrimental', 'Jolt', 'Single')
    -- local artap = common.findspell('Taps', 'Power Tap', 'Single', 2)
    -- local actap = common.findspell('Taps', 'Power Tap', 'Single')
    -- local hptap = common.findspell('Taps', 'Duration Tap', 'Single')
    -- local dd = common.findspell('Direct Damage', 'Disease', 'Single')
    -- local dot = common.findspell('Damage Over Time', 'Disease', 'Single')

    -- if target ~= nil and target ~= 0 then
    --     spells.CastAndBlock(aggro, 2, target)
    --     mq.cmd('/target id ' .. target)
    --     mq.delay(250)
    --     mq.cmd('/attack on')
    --     mq.delay(250)
    --     if mq.TLO.Pet() ~= "NO PET" then
    --         mq.cmd('/pet attack')
    --     end
    --     mq.delay(2250)
    --     --common.castAndBlock(dd, 1, target)
    --     --common.castAndBlock(artap, 5, target)
    --     --common.castAndBlock(actap, 9, target)
    --     --common.castAndBlock(dot, 6, target)
    -- end

end

return {
    Run = function(...)
        if MyClass.Name == 'Shadow Knight' then
            shd_attack()
        end
    end
}
