local mq = require('mq')
local str   = require('str')
local group = require('group')
require('eqclass')

local MyClass = EQClass:new()

local function name_of_caster()
    local idx = group.FirstOfClass('Enchanter')
    if idx < 0 then
        return ''
    end
    return mq.TLO.Group.Member(idx).Name()
end

local function send_spell(caster, type, target_id)
    mq.cmd('/squelch /bct ' .. caster .. ' //drive cast -spell|Direct Damage,' .. type .. ',Single -target|' .. target_id)
end

local function dd_target_id(type, id)
    local caster = name_of_caster()
    if caster:len() > 0 then
        send_spell(caster, type, id)
    end
end

local function dd_main_assist_target(type)
    dd_target_id(type, mq.TLO.Me.GroupAssistTarget.ID())
end

return {
    Run = function(...)
        local args = { ... }
        local type = args[1]:lower()
        if type == 'magic' or type == 'stun' then
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
