local mq = require('mq')
require('eqclass')


local actionqueue = {}

local MyClass = EQClass:new()
local State = {}
local Config = {}


local function set_tether(args)
    local mode = args[1]
    if mode == 'camp' then
        print('Camp set')
        State:TetherCamp()
    elseif mode == 'follow' then
        local search = mq.TLO.Group.Member(1).ID()
        if #args > 1 then search = args[2] end
        local id = mq.TLO.Spawn(search).ID()
        if id == nil or id == 0 then
            print('Could not find spawn: ' .. search)
            State:TetherClear()
        else
            print('Following id ' .. id)
            State:TetherFollow(id)
        end
    elseif mode == 'flee' then
        local search = mq.TLO.Group.Member(1).ID()
        if #args > 1 then search = args[2] end
        local id = mq.TLO.Spawn(search).ID()
        if id == nil or id == 0 then
            print('Could not find spawn: ' .. search)
            State:TetherClear()
        else
            print('Fleeing behind id ' .. id .. '!!!!!!!!!!!!!!')
            State:TetherFlee(id)
        end
    elseif mode == 'clear' then
        print('Clearing tether')
        State:TetherClear()
    end
end

return {
    Run = function(...)
        local args = { ... }
        set_tether(args)
    end,
    Init = function(state, cfg, aq)
        State = state
        Config = cfg
        actionqueue = aq
    end
}
