local mq = require('mq')

local group = {}

local last_checked = 0
function group.MainAssistCheck(timeout)
	if not mq.TLO.Group.MainAssist() then
		if last_checked + timeout < mq.gettime() then
			last_checked = mq.gettime()
			return true
		end
	end
end

function group.IsPuller(name)
	return mq.TLO.Group.Puller() ~= nil and mq.TLO.Group.Puller.Name() == name
end

function group.IsMainTank(name)
	return mq.TLO.Group.MainTank() ~= nil and mq.TLO.Group.MainTank.Name() == name
end

function group.IsMainAssist(name)
	return mq.TLO.Group.MainAssist() ~= nil and mq.TLO.Group.MainAssist.Name() == name
end

function group.FirstOfClass(class_name)
	if mq.TLO.Me.Grouped() then
        for i=0, mq.TLO.Group.GroupSize()-1 do
            if class_name == mq.TLO.Group.Member(i).Class.ShortName() or class_name == mq.TLO.Group.Member(i).Class.Name() then
				return i
            end
        end
    end
	return -1
end

function group.IsGroupMember(id)
	if mq.TLO.Me.Grouped() then
        for i=1, mq.TLO.Group.GroupSize()-1 do
            if id == mq.TLO.Group.Member(i).ID() then
				return true
            end
        end
    end
	return false
end

function group.IDs()
	local ids = {}
	if mq.TLO.Me.Grouped() then
        for i=0, mq.TLO.Group.GroupSize()-1 do
			table.insert(ids, mq.TLO.Group.Member(i).ID())
        end
    end
	return ids
end

return group