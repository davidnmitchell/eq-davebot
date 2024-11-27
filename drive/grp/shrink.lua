local mq = require('mq')
local co = require('co')
local group = require('group')
local spells = require('spells')
local teamevents = require('teamevents')
require('eqclass')

local MyClass = EQClass:new()

local function name_of_caster()
    local i = group.FirstOfClass('Shaman')
    local spell_key = 'shrink15'
    if i < 0 then
        i = group.FirstOfClass('Beastlord')
        if i < 0 then
            return '', ''
        end
        spell_key = 'shrink23'
    end
    return mq.TLO.Group.Member(i).Name(), spell_key
end

local function send_spell(caster, spell_key, target_id)
    mq.cmd('/squelch /bct ' .. caster .. ' //drive cast -spell|' .. spell_key .. ' -target|' .. target_id)
end

local function shrink_me()
    local caster, spell_key = name_of_caster()
    if caster:len() > 0 then
        send_spell(caster, spell_key, mq.TLO.Me.ID())
    end
end

local function shrink_name(name)
    local caster, spell_key = name_of_caster()
    local target_id = mq.TLO.Spawn(name).ID()
    if caster:len() > 0 and target_id ~= nil and target_id > 0 then
        send_spell(caster, spell_key, target_id)
    end
end

local function shrink_all()
    local caster, spell_key = name_of_caster()
    for i, id in ipairs(group.IDs()) do
        send_spell(caster, spell_key, id)
    end
end

local function shrink_bigs()
    local caster, spell_key = name_of_caster()
    for i=0, mq.TLO.Group.GroupSize()-1 do
        print(mq.TLO.Group.Member(i).Name() .. ':' .. mq.TLO.Group.Member(i).Height())
        if mq.TLO.Group.Member(i).Height() >= 4.0 then
            send_spell(caster, spell_key, mq.TLO.Group.Member(i).ID())
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
