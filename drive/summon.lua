local mq = require('mq')
local co = require('co')
local mychar = require('mychar')
local inventory = require('inventory')
require('eqclass')
require('actions.action')
require('actions.script')
require('actions.s_summon')
local spells    = require('spells')


local actionqueue = {}

local MyClass = EQClass:new()
local State = {}
local Config = {}



function ActGive(target_id)
    assert(target_id and target_id > 0)

    local self = Action('Give')
    self.__type__ = 'ActGive'

    ---@diagnostic disable-next-line: duplicate-set-field
    self.Run = function(state, cfg, ctx)
        inventory.GiveFromCursor(target_id)
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.IsFinished = function(state, cfg, ctx)
        return not mq.TLO.Window('TradeWnd').Open()
    end

    return self
end

function ActCloseInventory()
    local self = Action('Cleanup')
    self.__type__ = 'ActCloseInventory'

    ---@diagnostic disable-next-line: duplicate-set-field
    self.Run = function(state, cfg, ctx)
        mq.TLO.Window('InventoryWindow').DoClose()
    end

     ---@diagnostic disable-next-line: duplicate-set-field
    self.IsFinished = function(state, cfg, ctx)
        return not mq.TLO.Window('InventoryWindow').Open()
    end

    return self
end

function ScpSummonAndGiveSingle(
    spell_name,
    item,
    preferred_gem,
    target_id,
    priority,
    callback
)
    local queue = {}
    table.insert(queue, ScpSummon(spell_name, item, preferred_gem, priority, false, callback))
    table.insert(queue, ActGive(target_id))
    table.insert(queue, ActCloseInventory())

    local self = Script(
        'summonandgive ' .. item,
        queue,
        mq.TLO.Spell(spell_name).CastTime() + 10000,
        priority,
        true,
        callback
    )
    self.__type__ = 'ScpSummonAndGiveSingle'

    self._spell_name = spell_name
    self._target_id = target_id

    local function i_have_enough_mana()
        return mq.TLO.Me.CurrentMana() >= mq.TLO.Spell(spell_name).Mana()
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.IsSame = function(script)
        return script ~= nil and self.__type == script.__type__ and spell_name == script._spell_name and target_id == script._target_id
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.IsReady = function(state, cfg, ctx)
        return mychar.ReadyToCast() and i_have_enough_mana() and not mychar.IAmInvisible()
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.IsFinished = function(state, cfg, ctx)
        return not mq.TLO.Window('TradeWnd').Open()
    end

    return self
end






local Summoning = false


local function summon_callback()
    Summoning = false
end

local function summon(spell, item, put_in_inventory)
    if not mychar.InCombat() then
        Summoning = true
        print(spell)
        actionqueue.AddUnique(
            ScpSummon(
                spell,
                item,
                Config.SpellBar.FirstOpenGem(),
                40,
                put_in_inventory,
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

local function spell_from_arg(arg)
    local castable = Config.Spells.Spell(arg)
    if castable.Error == nil then
        return castable.Name
    end
    local name = spells.ReferenceSpell(arg)
    if name ~= nil then return name end
    assert(false, 'Could not find spell "' .. arg .. '"')
end

return {
    Run = function(...)
        local args = { ... }

        if mq.TLO.Cursor.ID() == nil then
            if args[1] == 'food' then
                local min_count = tonumber(args[2]) or 10
                local target = args[3] or ''

                local item = ''
                local spell = ''
                if MyClass.Name == 'Shaman' or MyClass.Name == 'Magician' or MyClass.Name == 'Cleric' or MyClass.Name == 'Druid' or MyClass.Name == 'Beastlord' then
                    item = 'Summoned: Black Bread'
                    spell = 'Summon Food'
                end
                while summoned_count(item) < min_count do
                    summon(spell, item, true)
                end
                print(target)
                if target:len() > 0 then
                    if tonumber(target) == nil then
                        target = mq.TLO.Spawn(target).ID()
                    end
                    inventory.GiveFromInventory(item, target)
                end
            elseif args[1] == 'drink' then
                local min_count = tonumber(args[2]) or 10
                local target = args[3] or ''

                local item = ''
                local spell = ''
                if MyClass.Name == 'Shaman' or MyClass.Name == 'Magician' or MyClass.Name == 'Cleric' or MyClass.Name == 'Druid' or MyClass.Name == 'Beastlord' then
                    item = 'Summoned: Globe of Water'
                    spell = 'Summon Drink'
                end
                while summoned_count(item) < min_count do
                    summon(spell, item, true)
                end
                print(target)
                if target:len() > 0 then
                    if tonumber(target) == nil then
                        target = mq.TLO.Spawn(target).ID()
                    end
                    inventory.GiveFromInventory(item, target)
                end
            elseif args[1] == 'weapon' then
                local spell = 'Blade of the Kedge' -- TODO: query this from somewhere
                local item = 'Summoned: ' .. spell
                local target = args[2] or ''
                local has_target = target:len() > 0

                if has_target then
                    if tonumber(target) == nil then
                        target = mq.TLO.Spawn(target).ID()
                    else
                        target = tonumber(target)
                    end

                    actionqueue.AddUnique(
                        ScpSummonAndGiveSingle(
                            spell,
                            item,
                            Config.SpellBar.FirstOpenGem(),
                            target,
                            40
                        )
                    )
                end
            elseif args[1] == 'waist' then
                local spell = 'Girdle of Magi`Kot' -- TODO: query this from somewhere
                local item = 'Summoned: ' .. spell
                local target = args[2] or ''
                local has_target = target:len() > 0

                if has_target then
                    if tonumber(target) == nil then
                        target = mq.TLO.Spawn(target).ID()
                    else
                        target = tonumber(target)
                    end

                    actionqueue.AddUnique(
                        ScpSummonAndGiveSingle(
                            spell,
                            item,
                            Config.SpellBar.FirstOpenGem(),
                            target,
                            40
                        )
                    )
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
