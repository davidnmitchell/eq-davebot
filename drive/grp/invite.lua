local mq = require('mq')
local co = require('co')
local str = require('str')
require('eqclass')

local MyClass = EQClass:new()

local function do_thing()
    local name_str = mq.TLO.EQBC.Names()
    local names = str.Split(name_str, ' ')

    for i=1,#names do
        print('Inviting ' .. names[i])
        mq.cmd('/invite ' .. names[i])
    end
    co.delay(1000)
    mq.cmd('/bca //invite')
end

return {
    Run = function(...)
        local args = { ... }
        do_thing()
    end
}
