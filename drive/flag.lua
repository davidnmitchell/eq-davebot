local mq = require('mq')
require('eqclass')


local actionqueue = {}

local MyClass = EQClass:new()
local State = {}
local Config = {}


return {
    Run = function(...)
        local args = { ... }
        local on_or_off = args[2] or 'on'
        if on_or_off == 'on' then
            State:SetFlag(args[1])
        elseif on_or_off == 'off' then
            State:UnsetFlag(args[1])
        end
    end,
    Init = function(state, cfg, aq)
        State = state
        Config = cfg
        actionqueue = aq
    end
}
