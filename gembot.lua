local mq = require('mq')
local spells = require('spells')
local mychar = require('mychar')
local co = require('co')

local gembot = {}


--
-- Globals
--

local Config = {}


--
-- Functions
--

local function log(msg)
	print('(gembot) ' .. msg)
end

local function do_memorize()
	local gems = Config:SpellBar():Gems()
	for gem,spell_key in pairs(gems) do
		if spell_key ~= 'OPEN' then
			local spell = Config:Spells():Spell(spell_key)
			if spell.Error == nil then
				if mq.TLO.Me.Gem(gem).Name() ~= spell.Name then

					if not MyClass.IsBard or not mq.TLO.DaveBot.States.IsBardCastActive() then
						if MyClass.IsBard then
							mq.TLO.DaveBot.States.BardCastIsActive()
							mq.cmd('/twist clear')
							co.delay(100)
						end

						if mq.TLO.Me.Gem(spell_key) then
							mq.cmd('/memspellslot ' .. gem ..' 0')
							co.delay(500)
						end

						mq.cmd('/memorize "' .. spell.Name .. '" gem' .. gem)

						---@diagnostic disable-next-line: undefined-field
						co.delay(10000, function() return mq.TLO.Cast.Ready(gem)() end)
						if MyClass.IsBard then
							mq.TLO.DaveBot.States.BardCastIsInactive()
						end
					end

				end
			else
				log(spell.Error)
			end
		end
	end
end


--
-- Init
--

function gembot.Init(cfg)
	Config = cfg
end


---
--- Main Loop
---

function gembot.Run()
	while true do
		if not mychar.InCombat() then
			do_memorize()
		end

		co.yield()
	end
end

return gembot