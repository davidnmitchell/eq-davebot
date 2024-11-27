local mq = require('mq')
require('eqclass')


local actionqueue = {}

local MyClass = EQClass:new()
local State = {}
local Config = {}


return {
    Run = function(...)
        local args = { ... }
        if args[1] == nil then
            print('------ Flags ------')
            if #State.Flags == 0 then
                print('No flags set')
            else
                for i, flag in ipairs(State.Flags) do
                    print(flag)
                end
            end
            print('-----------------------')
        else
            local on_or_off = (args[2] or 'on'):lower()
            if on_or_off == 'on' then
                State.SetFlag(args[1])
                Config.Refresh()
            elseif on_or_off == 'off' then
                State.UnsetFlag(args[1])
                Config.Refresh()
            end
        end
    end,
    Init = function(state, cfg, aq)
        State = state
        Config = cfg
        actionqueue = aq
    end
}
