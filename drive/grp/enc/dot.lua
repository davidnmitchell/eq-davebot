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
    mq.cmd('/squelch /bct ' .. caster .. ' //dbcq queue -spell|Damage Over Time,' .. type .. ',Single -target_id|' .. target_id)
end

local function do_target_id(type, id)
    local caster = name_of_caster()
    if caster:len() > 0 then
        send_spell(caster, type, id)
    end
end

local function do_main_assist_target(type)
    do_target_id(type, mq.TLO.Me.GroupAssistTarget.ID())
end

return {
    Run = function(...)
        local args = { ... }
        local type = (args[1] or 'magic'):lower()
        if type == 'magic' then
            type = str.FirstToUpper(type)
            local target = args[2] or 'mainassist'
            if target == 'mainassist' then
                do_main_assist_target(type)
            else
                do_target_id(type, tonumber(target))
            end
        else
            print('Invalid type: ' .. type)
        end
    end
}
