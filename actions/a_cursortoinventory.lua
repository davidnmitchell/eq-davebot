local spells = require('spells')
local co = require('co')
require('actions.action')


function ActCursorToInventory()
    local self = Action('CursorToInventory')

    ---@diagnostic disable-next-line: duplicate-set-field
    self.Run = function(state, cfg, ctx)
        co.delay(1000, function() return mq.TLO.Cursor.ID() ~= nil end)
        co.delay(500)
        mq.cmd('/autoinventory')
        co.delay(10000, function() return mq.TLO.Cursor.ID() == nil end)
    end

    return self
end
