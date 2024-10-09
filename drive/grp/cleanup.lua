local mq = require('mq')
require('eqclass')
local group = require('group')


local MyClass = EQClass:new()


local function do_thing()
    group.TellAll('/cleanup')
end

return {
    Run = function(...)
        local args = { ... }
        do_thing()
    end
}
