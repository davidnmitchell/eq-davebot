local mq = require('mq')
require('eqclass')
local group = require('group')

local MyClass = EQClass:new()

local function set_mode(mode)
    group.TellAll('/drive mode ' .. mode)
end

return {
    Run = function(...)
        local args = { ... }
        set_mode(args[1])
    end
}
