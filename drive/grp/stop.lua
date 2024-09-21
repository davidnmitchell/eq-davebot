local mq = require('mq')
local co = require('co')
require('eqclass')

local MyClass = EQClass:new()

local function stop()
    mq.cmd('/bcaa //drive stop')
end

return {
    Run = function(...)
        local args = { ... }
        stop()
    end
}
