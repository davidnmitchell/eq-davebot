local mq = require('mq')
local spells = require('spells')
local mychar = require('mychar')
local co = require('co')


--
-- Globals
--

GemBot = {}
GemBot.__index = GemBot


--
-- CTor
--

function GemBot:new(config)
	local obj = {}
	setmetatable(obj, GemBot)

	obj._config = config

	return obj
end


--
-- Methods
--

function GemBot:_log(msg)
	print('(gembot) ' .. msg)
end

function GemBot:Memorize()
	local gems = self._config:SpellBar():Gems()
	for gem,spell_key in pairs(gems) do
		if spell_key ~= 'OPEN' then
			local spell_reference = self._config:Spells():Spell(spell_key)
			if spell_reference ~= '' then
				local spell_name = spells.ReferenceSpell(spell_reference)
				if spell_name ~= '' then
					if mq.TLO.Me.Gem(gem).Name() ~= spell_name then

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

							mq.cmd('/memorize "' .. spell_name .. '" gem' .. gem)

							---@diagnostic disable-next-line: undefined-field
							co.delay(10000, function() return mq.TLO.Cast.Ready(gem)() end)
							if MyClass.IsBard then
								mq.TLO.DaveBot.States.BardCastIsInactive()
							end
						end

					end
				else
					print('Could not find spell for ' .. spell_reference)
				end
			else
				print('No key found under [Spells] for ' .. spell_key)
			end
		end
	end
end

function GemBot:Run()
	while true do
		if not mychar.InCombat() then
			self:Memorize()
		end

		co.yield()
	end
end
