local mq = require('mq')
local co = require('co')
local group = require('group')
local spells = require('spells')
local teamevents = require('teamevents')
require('eqclass')

local MyClass = EQClass:new()

local function stop()
    mq.cmd('/makecamp off')
	mq.cmd('/easyfind stop')
	mq.cmd('/travelto stop')
	mq.cmd('/nav stop')
	mq.cmd('/afollow off')
    mq.cmd('/dbtether none')
end

return {
    Run = function(...)
        local args = { ... }
        stop()
    end
}
