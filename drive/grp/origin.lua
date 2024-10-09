local mq = require('mq')
require('eqclass')
local co = require('co')
local group = require('group')

local MyClass = EQClass:new()

local function do_thing()
    group.TellAll('/dbcq pause 40')
    co.delay(1000)
    group.TellAll('/dbcq pause 35')
    co.delay(1000)
    group.TellAll('/twist clear', function(i) return mq.TLO.Group.Member(i).Class.Name() == 'Bard' end)
    co.delay(1000)
    group.TellAll('/casting "Origin" alt')
end

return {
    Run = function(...)
        local args = { ... }
        do_thing()
    end
}
