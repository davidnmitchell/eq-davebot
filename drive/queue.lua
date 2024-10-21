local mq = require('mq')
require('eqclass')


local actionqueue = {}

local MyClass = EQClass:new()
local State = {}
local Config = {}


return {
    Run = function(...)
        local args = { ... }
        local cmd = args[1]
        if cmd == 'wipe' then
            actionqueue.Wipe()
        end
    end,
    Init = function(state, cfg, aq)
        State = state
        Config = cfg
        actionqueue = aq
    end
}
