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

local function send_spell(caster, type, target_id)
    mq.cmd('/squelch /bct ' .. caster .. ' //drive cast -spell|Direct Damage,' .. type .. ',Single -target|' .. target_id .. ' -max_tries|10')
end

local function dd_target_id(type, id)
    local caster = name_of_caster()
    if caster:len() > 0 then
        send_spell(caster, type, id)
    end
end

local function dd_main_assist_target(type)
    ---@diagnostic disable-next-line: undefined-field
    local target_id = mq.TLO.Me.GroupAssistTarget.ID()
    -- if target_id == nil or target_id == 0 then
    --     print('No main assist target')
    --     return
    -- end
    dd_target_id(type, target_id)
end

return {
    Run = function(...)
        local args = { ... }
        local type = args[1]:lower()
        if type == 'cold' or type == 'poison' then
            type = str.FirstToUpper(type)
            if #args == 1 or args[2] == 'mainassist' then
                dd_main_assist_target(type)
            else
                dd_target_id(type, tonumber(args[2]))
            end
        else
            print('Invalid type: ' .. type)
        end
    end
}
