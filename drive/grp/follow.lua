local mq = require('mq')
local co = require('co')
local group = require('group')
local spells = require('spells')
local teamevents = require('teamevents')
require('eqclass')

local MyClass = EQClass:new()

local function follow_me()
    mq.cmd('/bcaa //makecamp off')
	mq.cmd('/bcaa //easyfind stop')
	mq.cmd('/bcaa //travelto stop')
	mq.cmd('/bcaa //nav stop')
	mq.cmd('/bcaa //afollow off')

    mq.cmd('/dbtether none')
    mq.cmd('/bca //dbtether ' .. mq.TLO.Me.Name())
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
