local mq = require('mq')

while true do
	if mq.TLO.Window('AlertWnd').Open() then
		mq.cmd('/notify AlertWnd ALW_Dismiss_Button leftmouseup')
	end
	mq.delay(100)
end