local mq = require('mq')
local co = require('co')
local mychar = require('mychar')
local inventory = require('inventory')
require('eqclass')
require('actions.s_summon')


local actionqueue = {}

local MyClass = EQClass:new()
local State = {}
local Config = {}

local Summoning = false


local function summon_callback()
    Summoning = false
end

local function summon(spell, item)
    if not mychar.InCombat() then
        Summoning = true
        actionqueue.AddUnique(
            ScpSummon(
                spell,
                item,
                5,
                40,
                summon_callback
            )
        )
        co.delay(30000, function() return not Summoning end)
        -- mq.cmd.echo(string.format('\awSummoning \ag%s', item))
        -- spells.QueueSpellIfNotQueued(State, spell)
        -- co.delay(timer + 10000, function() return mq.TLO.Cursor.ID() ~= nil end)
        -- co.delay(500)
        -- mq.cmd('/autoinventory')
        -- co.delay(10000, function() return mq.TLO.Cursor.ID() == nil end)
    end
end

local function summoned_count(item)
    return mq.TLO.FindItemCount(string.format('=%s', item))()
end

return {
    Run = function(...)
        local args = { ... }
        local min_count = tonumber(args[2]) or 10
        local target = args[3] or ''

        if mq.TLO.Cursor.ID() == nil then
            if args[1] == 'food' then
                local item = ''
                local spell = ''
                if MyClass.Name == 'Shaman' or MyClass.Name == 'Magician' or MyClass.Name == 'Cleric' or MyClass.Name == 'Druid' or MyClass.Name == 'Beastlord' then
                    item = 'Summoned: Black Bread'
                    spell = 'Summon Food'
                end
                while summoned_count(item) < min_count do
                    summon(spell, item)
                end
                print(target)
                if target:len() > 0 then
                    if tonumber(target) == nil then
                        target = mq.TLO.Spawn(target).ID()
                    end
                    inventory.Give(item, target)
                end
            end
            if args[1] == 'drink' then
                local item = ''
                local spell = ''
                if MyClass.Name == 'Shaman' or MyClass.Name == 'Magician' or MyClass.Name == 'Cleric' or MyClass.Name == 'Druid' or MyClass.Name == 'Beastlord' then
                    item = 'Summoned: Globe of Water'
                    spell = 'Summon Drink'
                end
                while summoned_count(item) < min_count do
                    summon(spell, mq.TLO.Spell(spell).CastTime(), item)
                end
                print(target)
                if target:len() > 0 then
                    if tonumber(target) == nil then
                        target = mq.TLO.Spawn(target).ID()
                    end
                    inventory.Give(item, target)
                end
            end
        end
    end,
    Init = function(state, cfg, aq)
        State = state
        Config = cfg
        actionqueue = aq
    end
}
