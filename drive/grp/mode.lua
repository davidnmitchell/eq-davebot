local mq = require('mq')
require('eqclass')

local MyClass = EQClass:new()

local function set_mode(mode)
    mq.cmd('/bcaa //drive mode ' .. mode)
end

return {
    Run = function(...)
        local args = { ... }
        set_mode(args[1])
    end
}
