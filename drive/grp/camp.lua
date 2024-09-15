local mq = require('mq')
require('eqclass')
local co = require('co')

local MyClass = EQClass:new()

local function do_thing()
    mq.cmd('/bcaa //dbcq pause 40')
    co.delay(1000)
    mq.cmd('/bcaa //dbcq pause 35')
    co.delay(1000)
    for i=0,mq.TLO.Group.GroupSize()-1 do
        if mq.TLO.Group.Member(i).Class.Name() == 'Bard' then
            mq.cmd('/bct ' .. mq.TLO.Group.Member(i).Name() .. ' //twist clear')
        end
    end
    co.delay(1000)
    mq.cmd('/bcaa //camp desktop fast')
end

return {
    Run = function(...)
        local args = { ... }
        do_thing()
    end
}
