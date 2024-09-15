local mq = require('mq')
local co = require('co')


local mychar = {}


function mychar.ReadyToCast()
	return not mq.TLO.Me.Stunned()
		and not	mq.TLO.Me.Dead()
		and not mq.TLO.Me.Feigning()
		and not	mq.TLO.Me.Ducking()
		and not mq.TLO.Me.Silenced()
		and not mq.TLO.Me.Charmed()
		and not mq.TLO.Me.Mezzed()
		and not mq.TLO.Me.Invulnerable()
		and not mq.TLO.Me.Moving()
		and mq.TLO.Cast.Status() == 'I'
end

function mychar.Casting()
	local status = mq.TLO.Cast.Status()
	return status ~= 'C'
end

function mychar.InCombat()
	return mq.TLO.Me.XTarget() > 0 -- or mq.TLO.Me.CombatState() == 'COMBAT'
	-- for i=1,mq.TLO.DanNet.PeerCount() do
		-- local peer = mq.TLO.DanNet.Peers(i)()
		-- local combat = common.query(peer, 'Me.Combat')
		-- if combat then
			-- return true
		-- end
	-- end
	-- return false
end

function mychar.CanRest()
	return mq.TLO.Me.CombatState() == 'ACTIVE'
end

function mychar.Standing()
	return mq.TLO.Me.State() == 'STAND'
end


local function moving()
	local loc = mq.TLO.Me.MQLoc()
	local m = loc ~= _MyChar_LastLoc
	_MyChar_LastLoc = loc
	return m
end

function mychar.StillForSeconds()
	return (mq.gettime() - _MyChar_StillSince) / 1000
end


--
-- Init
--

function mychar.Init(cfg)
	--Config = cfg
	--Ini = cfg._ini

	_MyChar_StillSince = 0
	_MyChar_LastLoc = ''
end


---
--- Main Loop
---

function mychar.Run()
	while true do
		if moving() then
			_MyChar_StillSince = mq.gettime()
		end

		co.yield()
	end
end

return mychar