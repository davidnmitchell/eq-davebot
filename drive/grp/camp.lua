local mq = require('mq')
local co = require('co')
local group = require('group')
require('eqclass')


local actionqueue = {}

local MyClass = EQClass:new()
local State = {}
local Config = {}


local function do_thing()
    group.TellAll('/drive mode 1')
    co.delay(1000)
    group.TellAll('/drive queue wipe')
    co.delay(1000)
    group.TellAll('/twist clear', function(i) return mq.TLO.Group.Member(i).Class.Name() == 'Bard' end)
    co.delay(1000)
    group.TellAll('/camp desktop fast')
end

return {
    Run = function(...)
        local args = { ... }
        do_thing()
    end,
    Init = function(state, cfg, aq)
        State = state
        Config = cfg
        actionqueue = aq
    end
}
