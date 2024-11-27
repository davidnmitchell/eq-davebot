local mq = require('mq')
local str   = require('str')
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

local function send_spell(caster, target_id)
    mq.cmd('/squelch /bct ' .. caster .. ' //drive cast -spell|Utility Detrimental,Slow,Single -target|' .. target_id .. ' -max_tries|2')
end

local function slow_target_id(target_id)
    local caster = name_of_caster()
    if caster:len() > 0 then
        send_spell(caster, target_id)
    end
end

local function slow_main_assist_target()
    ---@diagnostic disable-next-line: undefined-field
    local target_id = mq.TLO.Me.GroupAssistTarget.ID()
    if target_id == nil or target_id == 0 then
        print('No main assist target')
        return
    end
    slow_target_id(target_id)
end

return {
    Run = function(...)
        local args = { ... }
        if #args == 0 or args[1] == 'mainassist' then
            slow_main_assist_target()
        else
            slow_target_id(tonumber(args[1]))
        end
    end
}
