local mq = require('mq')
local group = require('group')
require('eqclass')


local MyClass = EQClass:new()


local function stop()
    group.TellAll('/drive stop')
end

return {
    Run = function(...)
        local args = { ... }
        stop()
    end
}
