local mq = require('mq')
require('eqclass')


local MyClass = EQClass:new()


local function do_thing()
    mq.cmd('/bcaa //cleanup')
end

return {
    Run = function(...)
        local args = { ... }
        do_thing()
    end
}
