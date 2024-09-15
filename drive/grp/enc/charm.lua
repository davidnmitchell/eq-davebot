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

local function send_spell(caster, target_id)
    mq.cmd('/squelch /bct ' .. caster .. ' //dbcq queue -spell|Utility Detrimental,Charm,Single -target_id|' .. target_id)
end

local function do_target_id(id)
    local caster = name_of_caster()
    if caster:len() > 0 then
        send_spell(caster, id)
    end
end

local function do_main_assist_target()
    do_target_id(mq.TLO.Me.GroupAssistTarget.ID())
end

return {
    Run = function(...)
        local args = { ... }
        if #args == 0 or args[1] == 'mainassist' then
            do_main_assist_target()
        else
            do_target_id(tonumber(args[1]))
        end
    end
}
