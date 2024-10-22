local mq = require('mq')
local common = require('common')
local netbots= require('netbots')

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

function group.TellAll(cmd, predicate)
	if mq.TLO.Me.Grouped() then
		predicate = predicate or function() return true end
		for i=1, mq.TLO.Group.Members() do
			if predicate(i) then
				local name = mq.TLO.Group.Member(i).Name()
				if name ~= nil then
					mq.cmd('/squelch /bct ' .. name .. ' /' .. cmd)
				end
			end
		end
		if predicate(0) then
			mq.cmd(cmd)
		end
	end
end

function group.FirstOfClass(class_name)
	if mq.TLO.Me.Grouped() then
        for i=0, mq.TLO.Group.Members() do
            if class_name == mq.TLO.Group.Member(i).Class.ShortName() or class_name == mq.TLO.Group.Member(i).Class.Name() then
				return i
            end
        end
    end
	return -1
end

function group.IsGroupMember(id)
	if mq.TLO.Me.Grouped() then
        for i=1, mq.TLO.Group.Members() do
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
        for i=0, mq.TLO.Group.Members() do
			table.insert(ids, mq.TLO.Group.Member(i).ID())
        end
    end
	return ids
end

function group.IndexOf(target_id)
	for i = 1, mq.TLO.Group.Members() do
		if target_id == mq.TLO.Group.Member(i).ID() then
			return i
		end
	end
	return 0
end

function group.PetIdById(target_id)
	if common.ArrayHasValue(netbots.PeerIds(), target_id) then
		return mq.TLO.NetBots(netbots.PeerById(target_id)).PetID() or 0
	elseif target_id == mq.TLO.Me.ID() then
		return mq.TLO.Pet.ID() or 0
	else
		return mq.TLO.Group.Member(group.IndexOf(target_id)).Pet.ID() or 0
	end
end

function group.MemberId(idx)
	if idx == 0 then
		return mq.TLO.Me.ID()
	end
	return mq.TLO.Group.Member(idx).ID()
end

return group