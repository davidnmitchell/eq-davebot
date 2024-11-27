local mq = require('mq')
require('eqclass')


local actionqueue = {}

local MyClass = EQClass:new()
local State = {}
local Config = {}


local function set_mode(mode)
    State.ChangeMode(mode)
    Config.Refresh()
end

return {
    Run = function(...)
        local args = { ... }
        set_mode(args[1])
    end,
    Init = function(state, cfg, aq)
        State = state
        Config = cfg
        actionqueue = aq
    end
}
