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

local function send_spell(caster, target_id)
    mq.cmd('/squelch /bct ' .. caster .. ' //drive cast -spell|h_ot -target|' .. target_id .. ' -max_tries|2')
end

local function hot_target_id(target_id)
    local caster = name_of_caster()
    if caster:len() > 0 then
        send_spell(caster, target_id)
    end
end

local function hot_main_assist_target()
    ---@diagnostic disable-next-line: undefined-field
    local target_id = mq.TLO.Me.GroupAssistTarget.ID()
    if target_id == nil or target_id == 0 then
        print('No main assist target')
        return
    end
    hot_target_id(target_id)
end

return {
    Run = function(...)
        local args = { ... }
        if #args == 0 or args[1] == 'mainassist' then
            hot_main_assist_target()
        else
            hot_target_id(tonumber(args[1]))
        end
    end
}
