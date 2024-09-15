local mq = require('mq')
local co = require('co')
local mychar = require('mychar')
local spells = require('spells')
local inventory = require('inventory')
require('eqclass')

local MyClass = EQClass:new()

local function summon(spell, timer, item)
    if not mychar.InCombat() then
        mq.cmd.echo(string.format('\awSummoning \ag%s', item))
        spells.QueueSpellIfNotQueued(spell)
        co.delay(timer + 10000, function() return mq.TLO.Cursor.ID() ~= nil end)
        co.delay(500)
        mq.cmd('/autoinventory')
        co.delay(10000, function() return mq.TLO.Cursor.ID() == nil end)
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
    end
}
