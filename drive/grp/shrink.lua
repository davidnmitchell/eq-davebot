local mq = require('mq')
local co = require('co')
local group = require('group')
local spells = require('spells')
local teamevents = require('teamevents')
require('eqclass')

local MyClass = EQClass:new()

local function name_of_caster()
    local i = group.FirstOfClass('Shaman')
    if i < 0 then
        i = group.FirstOfClass('Beastlord')
    end
    if i < 0 then
        return ''
    end
    return mq.TLO.Group.Member(i).Name()
end

local function send_spell(caster, target_id)
    mq.cmd('/squelch /bct ' .. caster .. ' //drive cast -spell|shrink15 -target|' .. target_id)
end

local function shrink_me()
    local caster = name_of_caster()
    if caster:len() > 0 then
        send_spell(caster,  mq.TLO.Me.ID())
    end
end

local function shrink_name(name)
    local caster = name_of_caster()
    local target_id = mq.TLO.Spawn(name).ID()
    if caster:len() > 0 and target_id ~= nil and target_id > 0 then
        send_spell(caster, target_id)
    end
end

local function shrink_all()
    local caster = name_of_caster()
    for i, id in ipairs(group.IDs()) do
        send_spell(caster, id)
    end
end

local function shrink_bigs()
    local caster = name_of_caster()
    for i=0, mq.TLO.Group.GroupSize()-1 do
        print(mq.TLO.Group.Member(i).Name() .. ':' .. mq.TLO.Group.Member(i).Height())
        if mq.TLO.Group.Member(i).Height() >= 4.0 then
            send_spell(caster, mq.TLO.Group.Member(i).ID())
        end
    end
end

return {
    Run = function(...)
        local args = { ... }
        if args[1] == 'me' then
            shrink_me()
        elseif args[1] == 'all' then
            shrink_all()
        elseif args[1] == 'bigs' then
            shrink_bigs()
        else
            shrink_name(args[1])
        end
    end
}
