local mq = require('mq')
local co = require('co')
local mychar = require('mychar')
local inventory = require('inventory')
require('eqclass')
require('actions.s_summon')
local spells    = require('spells')
local group     = require('group')


local actionqueue = {}

local MyClass = EQClass:new()
local State = {}
local Config = {}

function ActDestroyOnCursor()
    local self = Action('DestroyOnCursor')
    self.__type__ = 'ActDestroyOnCursor'

    ---@diagnostic disable-next-line: duplicate-set-field
    self.Run = function(state, cfg, ctx)
        while mq.TLO.Cursor() ~= nil do
            mq.cmd('/destroy')
            co.delay(500)
        end
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.IsFinished = function(state, cfg, ctx)
        return mq.TLO.Cursor() == nil
    end

    return self
end

function ScpDestroyOnCursor(
    callback
)
    local queue = {}
    table.insert(queue, ActDestroyOnCursor())

    local self = Script(
        'destroyoncursor',
        queue,
        nil,
        99,
        nil,
        callback
    )
    self.__type__ = 'ScpDestroyOnCursor'

    -- ---@diagnostic disable-next-line: duplicate-set-field
    -- self.IsSame = function(script)
    --     return script.Type == 'destroyoncursor'
    -- end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.IsReady = function(state, cfg, ctx)
        return mq.TLO.Cursor() ~= nil
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.IsFinished = function(state, cfg, ctx)
        return mq.TLO.Cursor() == nil
    end

    return self
end

local function name_of_caster()
    local idx = group.FirstOfClass('Magician')
    if idx < 0 then
        return ''
    end
    return mq.TLO.Group.Member(idx).Name()
end

local function send_cmd(name, cmd)
    mq.cmd('/squelch /bct ' .. name .. ' /' .. cmd)
end

local function do_cmd(cmd)
    local caster = name_of_caster()
    if caster:len() > 0 then
        send_cmd(caster, cmd)
    end
end


return {
    Run = function(...)
        local args = { ... }

        if args[1] == 'pet' then
            if args[2] == 'weapon' then
                print('grp mag summon pet weapon')
                for i = 0, mq.TLO.Group.Members() do
                    if mq.TLO.Group.Member(i).Pet() ~= 'NO PET' then
                        local count = 0
                        if mq.TLO.Group.Member(i).Pet.Equipment('primary')() == 0 then count = count + 1 end
                        if mq.TLO.Group.Member(i).Pet.Equipment('offhand')() == 0 then count = count + 1 end
                        print(mq.TLO.Group.Member(i).Name() .. "'s Pet needs " .. count .. ' weapons')
                        for j = 1, count do
                            local target = mq.TLO.Group.Member(i).Pet.ID()
                            do_cmd('/drive summon weapon ' .. target)
                            co.delay(500)
                        end
                    end
                end
            elseif args[2] == 'waist' then
                print('grp mag summon pet waist')
                for i = 0, mq.TLO.Group.Members() do
                    if mq.TLO.Group.Member(i).Pet() ~= 'NO PET' then
                        local target = mq.TLO.Group.Member(i).Pet.ID()
                        do_cmd('/drive summon waist ' .. target)
                    end
                end
                co.delay(1000)
                actionqueue.AddUnique(
                    ScpDestroyOnCursor()
                )
            end
        end
    end,
    Init = function(state, cfg, aq)
        State = state
        Config = cfg
        actionqueue = aq
    end
}
