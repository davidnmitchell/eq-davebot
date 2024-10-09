local mq = require('mq')
local co = require('co')
local group = require('group')
local spells = require('spells')
local teamevents = require('teamevents')
require('eqclass')

local MyClass = EQClass:new()

local function make_camp()
    group.TellAll('/makecamp off')
	group.TellAll('/easyfind stop')
	group.TellAll('/travelto stop')
	group.TellAll('/nav stop')
	group.TellAll('/afollow off')

    group.TellAll('/dbtether camp')
end

return {
    Run = function(...)
        local args = { ... }
        make_camp()
    end
}
