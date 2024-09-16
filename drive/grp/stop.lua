local mq = require('mq')
local co = require('co')
local group = require('group')
local spells = require('spells')
local teamevents = require('teamevents')
require('eqclass')

local MyClass = EQClass:new()

local function stop()
    mq.cmd('/bcaa //drive stop')
end

return {
    Run = function(...)
        local args = { ... }
        stop()
    end
}
