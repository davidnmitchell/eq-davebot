local mq = require('mq')
local co = require('co')
local str= require('str')
local common = require('common')

local tlo = {}


local function log(msg)
	print('(tlo) ' .. msg)
	-- co.delay(250)
end

--
-- Globals
--

local Config = {}
local Ini = {}

local Mode = { Mode = 1, Flags = {} }
local States = { CrowdControlActive = false, BardCastActive = false, EarlyCombatActive = false, EarlyCombatActiveSince = 0 }
local MyChar = { StillSince = 0, LastLoc = '' }
local Tether = { Status = 'N', Detail = 'NONE' }


--
-- DataTypes
--

local modeType = mq.DataType.new('ModeType', {
    Members = {
		Mode = function(_, mode)
			return 'int', mode.Mode
		end,
		FlagCount = function(_, mode)
			return 'int', #mode.Flags
		end,
		Flag = function(i, mode)
			return 'string', mode.Flags[i]
		end
    },

    Methods = {
		ModeIs = function(m, mode)
			local new_mode = tonumber(m)
			if new_mode ~= nil then
				mode.Mode = new_mode
				Ini:WriteNumber('State', 'Mode', mode.Mode)
				log('Mode is now ' .. mode.Mode)
			else
				log('Tried to set Mode to nil')
			end
		end,
		SetFlag = function(flag, mode)
			if flag ~= nil then
				if not common.ArrayHasValue(mode.Flags, flag) then
					table.insert(mode.Flags, flag)
					local csv = common.TableAsCsv(mode.Flags)
					Ini:WriteString('State', 'Flags', csv)
					log('Set Flag ' .. flag)
				end
			else
				log('Tried to set nil Flag')
			end
		end,
		UnsetFlag = function(flag, mode)
			if flag ~= nil then
				local idx = common.TableIndexOf(mode.Flags, flag)
				if idx > 0 then
					table.remove(mode.Flags, idx)
					local csv = common.TableAsCsv(mode.Flags)
					Ini:WriteString('State', 'Flags', csv)
					log('Unset Flag ' .. flag)
				end
			else
				log('Tried to unset nil Flag')
			end
		end,
		Read = function(_, mode)
			mode.Mode = Ini:Number('State', 'Mode', 1)
			mode.Flags = str.Split(Ini:String('State', 'Flags', ''), ',')
		end
    },

    ToString = function(_)
        return string.format('')
    end
})

local statesType = mq.DataType.new('StatesType', {
    Members = {
		IsCrowdControlActive = function(_, states)
			return 'bool', states.CrowdControlActive
		end,
		IsBardCastActive = function(_, states)
			return 'bool', states.BardCastActive
		end,
		IsEarlyCombatActive = function(_, states)
			return 'bool', states.EarlyCombatActive
		end,
		EarlyCombatActiveSince = function(_, states)
			return 'int', states.EarlyCombatActiveSince
		end
    },

    Methods = {
		CrowdControlIsActive = function(_, states)
			states.CrowdControlActive = true
		end,
		CrowdControlIsInactive = function(_, states)
			states.CrowdControlActive = false
		end,
		BardCastIsActive = function(_, states)
			states.BardCastActive = true
		end,
		BardCastIsInactive = function(_, states)
			states.BardCastActive = false
		end,
		EarlyCombatIsActive = function(_, states)
			states.EarlyCombatActive = true
			states.EarlyCombatActiveSince = mq.gettime()
		end,
		EarlyCombatIsInactive = function(_, states)
			states.EarlyCombatActive = false
		end
    },

    ToString = function(_)
        return string.format('')
    end
})

local myCharType = mq.DataType.new('MyCharType', {
    Members = {
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
		Mode = function(_, _)
			return modeType, Mode
		end,
		States = function(_, _)
			return statesType, States
		end,
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

	mq.TLO.DaveBot.Mode.Read()
	mq.TLO.DaveBot.Tether.Read()
end


---
--- Main Loop
---

function tlo.Run()
	log('Up and running')
	while true do
		if moving() then
			MyChar.StillSince = mq.gettime()
		end

		co.yield()
	end
end


return tlo
