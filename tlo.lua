local mq = require('mq')
local co = require('co')

local tlo = {}


--
-- Globals
--

local Config = {}
local Ini = {}

local MyChar = {StillSince = 0, LastLoc = ''}
local Tether = {Status = 'N', Detail = 'NONE'}

--
-- DataTypes
--

local myCharType = mq.DataType.new('MyCharType', {
    Members = {
		Casting = function(_, my_char)
			return 'bool', mq.TLO.Cast.Status() ~= 'C'
		end,
        ReadyToCast = function(_, my_char)
			local value = not mq.TLO.Me.Stunned()
				and not	mq.TLO.Me.Dead()
				and not mq.TLO.Me.Feigning()
				and not	mq.TLO.Me.Ducking()
				and not mq.TLO.Me.Silenced()
				and not mq.TLO.Me.Charmed()
				and not mq.TLO.Me.Mezzed()
				and not mq.TLO.Me.Invulnerable()
				and not mq.TLO.Me.Moving()
				and mq.TLO.Cast.Status() == 'I'
            return 'bool', value
        end,
		InCombat = function(_, my_char)
			return 'bool', mq.TLO.Me.XTarget() > 0 -- or mq.TLO.Me.CombatState() == 'COMBAT'
			-- for i=1,mq.TLO.DanNet.PeerCount() do
				-- local peer = mq.TLO.DanNet.Peers(i)()
				-- local combat = common.query(peer, 'Me.Combat')
				-- if combat then
					-- return true
				-- end
			-- end
			-- return false
		end,
		CanRest = function(_, mychar)
			return 'bool', mq.TLO.Me.CombatState() == 'ACTIVE'
		end,
		Standing = function(_, mychar)
			return 'bool', mq.TLO.Me.State() == 'STAND'
		end,
		HasNotMovedFor = function(_, my_char)
			return 'int', (mq.gettime() - my_char.StillSince) / 1000
		end
    },

    Methods = {
    },

    ToString = function(_)
        return string.format('')
    end
})

local tetherType = mq.DataType.new('TetherType', {
    Members = {
		Status = function(_, tether)
			return 'string', tether.Status
		end,
        Detail = function(_, tether)
            return 'string', tether.Detail
        end
    },

    Methods = {
		Clear = function(_, tether)
			tether.Status = 'N'
			tether.Detail = 'NONE'
			Ini:WriteString('State', 'Tether', tether.Detail)
		end,
		Follow = function(id, tether)
			tether.Status = 'F'
			tether.Detail = tostring(id)
			Ini:WriteString('State', 'Tether', tether.Detail)
		end,
		Camp = function(_, tether)
			tether.Status = 'C'
			tether.Detail = mq.TLO.Me.MQLoc()
			Ini:WriteString('State', 'Tether', tether.Detail)
		end,
		Read = function(_, tether)
			tether.Detail = tostring(Ini:String('State', 'Tether', 'NONE'))
			if tether.Detail == 'NONE' then
				tether.Status = 'N'
			elseif tonumber(tether.Detail) ~= nil then
				tether.Status = 'F'
			else
				tether.Status = 'C'
			end
		end
    },

    ToString = function(tether)
        return tether.Detail
    end
})

local daveBotType = mq.DataType.new('DaveBotType', {
    Members = {
		MyChar = function(_, _)
			return myCharType, MyChar
		end,
		Tether = function(_, _)
			return tetherType, Tether
		end
    },

    Methods = {
    },

    ToString = function(db)
        return string.format('')
    end
})

local function moving()
	local loc = mq.TLO.Me.MQLoc()
	local m = loc ~= MyChar.LastLoc
	MyChar.LastLoc = loc
	return m
end

local function DaveBot(param)
	return daveBotType, {}
end

--
-- Init
--

function tlo.Init(cfg)
	Config = cfg
	Ini = cfg._ini

	mq.AddTopLevelObject('DaveBot', DaveBot)
end


---
--- Main Loop
---

function tlo.Run()
	while true do
		if moving() then
			MyChar.StillSince = mq.gettime()
		end

		co.yield()
	end
end


return tlo