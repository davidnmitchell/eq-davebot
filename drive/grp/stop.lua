local mq = require('mq')
local co = require('co')
local group = require('group')
local spells = require('spells')
local teamevents = require('teamevents')
require('eqclass')

local MyClass = EQClass:new()

local function stop()
    mq.cmd('/bcaa //makecamp off')
	mq.cmd('/bcaa //easyfind stop')
	mq.cmd('/bcaa //travelto stop')
	mq.cmd('/bcaa //nav stop')
	mq.cmd('/bcaa //afollow off')
    mq.cmd('/bcaa //dbtether none')
end

return {
    Run = function(...)
        local args = { ... }
        stop()
    end
}
