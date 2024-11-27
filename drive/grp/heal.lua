local mq = require('mq')
local group = require('group')
require('eqclass')

local MyClass = EQClass:new()

local function name_of_caster()
    local idx = group.FirstOfClass('Cleric')
    if idx < 0 then
        idx = group.FirstOfClass('Shaman')
    end
    if idx < 0 then
        idx = group.FirstOfClass('Druid')
    end
    if idx < 0 then
        idx = group.FirstOfClass('Paladin')
    end
    if idx < 0 then
        return ''
    end
    return mq.TLO.Group.Member(idx).Name()
end

local function send_spell(caster, target_id)
    mq.cmd('/squelch /bct ' .. caster .. ' //drive cast -spell|h_single -priority|0 -target|' .. target_id)
end

local function heal_me()
    local caster = name_of_caster()
    if caster:len() > 0 then
        send_spell(caster,  mq.TLO.Me.ID())
    end
end

local function heal_tank()
    local caster = name_of_caster()
    if caster:len() > 0 then
        send_spell(caster,  mq.TLO.Group.MainTank.ID())
    end
end

local function heal_name(name)
    local caster = name_of_caster()
    local target_id = mq.TLO.Spawn(name).ID()
    if caster:len() > 0 and target_id ~= nil and target_id > 0 then
        send_spell(caster, target_id)
    end
end

return {
    Run = function(...)
        local args = { ... }
        if args[1] == 'me' then
            heal_me()
        elseif args[1] == 'maintank' then
            heal_tank()
        else
            heal_name(args[1])
        end
    end
}
