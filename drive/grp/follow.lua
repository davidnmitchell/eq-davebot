local mq = require('mq')
local co = require('co')
local group = require('group')
local spells = require('spells')
local teamevents = require('teamevents')
require('eqclass')


local MyClass = EQClass:new()


local function follow_me()
    group.TellAll('/makecamp off')
	group.TellAll('/easyfind stop')
	group.TellAll('/travelto stop')
	group.TellAll('/nav stop')
	group.TellAll('/afollow off')

    group.TellAll('/drive tether follow ' .. mq.TLO.Me.ID(), function(i) return i ~= 0 end)
end

return {
    Run = function(...)
        local args = { ... }
        if args[1] == 'me' then
            follow_me()
        else
            print('Not implemented to follow ' .. args[1])
        end
    end
}
