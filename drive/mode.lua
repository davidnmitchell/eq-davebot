local mq = require('mq')
require('eqclass')


local MyClass = EQClass:new()
local State = {}
local Config = {}


local function set_mode(mode)
    State:ChangeMode(mode)
end

return {
    Run = function(...)
        local args = { ... }
        set_mode(args[1])
    end,
    Init = function(state, cfg)
        State = state
        Config = cfg
    end
}
