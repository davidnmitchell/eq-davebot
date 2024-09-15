local mq = require('mq')
local str   = require('str')
local group = require('group')
require('eqclass')

local MyClass = EQClass:new()

local function name_of_caster()
    local idx = group.FirstOfClass('Magician')
    if idx < 0 then
        return ''
    end
    return mq.TLO.Group.Member(idx).Name()
end

local function send_spell(caster, type, target_id)
    mq.cmd('/squelch /bct ' .. caster .. ' //dbcq queue -spell|Direct Damage,' .. type .. ',Single -target_id|' .. target_id)
end

local function send_bolt_spell(caster, type, target_id)
    mq.cmd('/squelch /bct ' .. caster .. ' //dbcq queue -spell|Direct Damage,' .. type .. ',Line of Sight -target_id|' .. target_id)
end

local function do_target_id(type, id, func)
    local caster = name_of_caster()
    if caster:len() > 0 then
        func(caster, type, id)
    end
end

return {
    Run = function(...)
        local args = { ... }
        local type = args[1]:lower()
        if type == 'magic' or type == 'fire' or type == 'firebolt' then
            if type == 'magic' or type == 'fire' then
                type = str.FirstToUpper(type)
                if #args == 1 or args[2] == 'mainassist' then
                    do_target_id(type, mq.TLO.Me.GroupAssistTarget.ID(), send_spell)
                else
                    do_target_id(type, tonumber(args[2]), send_spell)
                end
            else
                type = 'Fire'
                if #args == 1 or args[2] == 'mainassist' then
                    do_target_id(type, mq.TLO.Me.GroupAssistTarget.ID(), send_bolt_spell)
                else
                    do_target_id(type, tonumber(args[2]), send_bolt_spell)
                end
            end
        else
            print('Invalid type: ' .. type)
        end
    end
}
