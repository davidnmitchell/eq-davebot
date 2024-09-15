local mq = require('mq')
require('eqclass')

local MyClass = EQClass:new()

return {
    Run = function(...)
        local args = { ... }
        if args[1] == 'lang' then
            mq.cmd('/bcaa //drive train lang ' .. args[2])
        end
    end
}
