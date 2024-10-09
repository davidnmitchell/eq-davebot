local mq = require('mq')
local group = require('group')
require('eqclass')


local MyClass = EQClass:new()


return {
    Run = function(...)
        local args = { ... }
        if args[1] == 'lang' then
            group.TellAll('/drive train lang ' .. args[2])
        end
    end
}
