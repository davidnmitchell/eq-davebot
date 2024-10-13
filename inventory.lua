local mq = require('mq')
local co = require('co')
local bc = require('bc')

local inventory = {}

-- TODO: select number to give
-- '/window open' will show open windows
function inventory.GiveFromCursor(target_id)
	mq.cmd('/target id ' .. target_id)
	co.delay(10000, function() return mq.TLO.Target.ID() == target_id end)
	mq.cmd('/click left target')
	co.delay(5000, function() return mq.TLO.Window('TradeWnd').Open() end)
	mq.cmd('/notify TradeWnd TRDW_Trade_Button leftmouseup')
	if bc.IsAPeer(target_id) then
		mq.cmd('/bct ' .. mq.TLO.Spawn(target_id).Name() .. ' //notify TradeWnd TRDW_Trade_Button leftmouseup')
	end
end

function inventory.GiveFromInventory(item_name, target_id)
	mq.cmd('/shiftkey /itemnotify "' .. item_name .. '" leftmouseup')
	co.delay(10000, function() return mq.TLO.Cursor.ID() ~= nil end)
	co.delay(500)
	inventory.GiveFromCursor(target_id)
end


return inventory