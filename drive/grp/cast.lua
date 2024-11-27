local mq = require('mq')
require('eqclass')
local group = require('group')

local MyClass = EQClass:new()

local function all_cast(spell)
    group.TellAll('/drive cast -spell|' .. spell)
end

return {
    Run = function(...)
        local args = { ... }
        all_cast(args[1])
    end
}
