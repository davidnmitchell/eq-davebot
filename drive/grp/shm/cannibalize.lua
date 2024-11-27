local mq = require('mq')
local group = require('group')
require('eqclass')

local MyClass = EQClass:new()

local function name_of_caster()
    local idx = group.FirstOfClass('Shaman')
    if idx < 0 then
        return ''
    end
    return mq.TLO.Group.Member(idx).Name()
end

local function send_spell(caster)
    mq.cmd('/squelch /bct ' .. caster .. ' //drive cast -spell|Utility Beneficial,Conversions,Self')
end

local function cannibalize(times)
    local caster = name_of_caster()
    if caster:len() > 0 then
        for i=1,times do
            send_spell(caster)
        end
    end
end

return {
    Run = function(...)
        local args = { ... }
        local times = tonumber(args[1]) or 1
        cannibalize(times)
    end
}
