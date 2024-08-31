local mq = require('mq')
local spells = require('spells')
local mychar = require('mychar')
local heartbeat = require('heartbeat')
require('eqclass')
require('botstate')
require('config')


--
-- Globals
--

local ProcessName = 'gembot'
local MyClass = EQClass:new()
local State = BotState:new(false, ProcessName, false, true)
local Spells = SpellsConfig:new()
local SpellBar = SpellBarConfig:new()

local Running = true


--
-- Functions
--

local function log(msg)
	print('(' .. ProcessName .. ') ' .. msg)
end

local function Memorize()
	local gems = SpellBar:Gems(State)
	for gem,spell_key in pairs(gems) do
		if spell_key ~= 'OPEN' then
			local spell_reference = Spells:Spell(spell_key)
			if spell_reference ~= '' then
				local spell_name = spells.ReferenceSpell(spell_reference)
				if spell_name ~= '' then
					if mq.TLO.Me.Gem(gem).Name() ~= spell_name then

						if not MyClass.IsBard or not State:BardCastActive() then
							if MyClass.IsBard then
								spells.UpdateBardCastActive()
								mq.delay(100)
								mq.cmd('/twist clear')
							end

							if mq.TLO.Me.Gem(spell_key) then
								mq.cmd('/memspellslot ' .. gem ..' 0')
								mq.delay(500)
							end

							mq.cmd('/memorize "' .. spell_name .. '" gem' .. gem)

							local timeout = mq.gettime() + 20000
							---@diagnostic disable-next-line: undefined-field
							while not mq.TLO.Cast.Ready(gem)() and timeout > mq.gettime() do
								mq.delay(10)
							end
							if MyClass.IsBard then spells.UpdateBardCastInactive() end
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

--
-- Main
--

local function main()
	while Running == true do
		mq.doevents()

		if not mychar.InCombat() then
		--if not MyClass.IsBard or not State:BardCastActive() then
			Memorize()
		end

		SpellBar:Reload(10000)
		Spells:Reload(20000)

		heartbeat.SendHeartBeat(ProcessName)
		mq.delay(1000)
	end
end


--
-- Execution
--

main()
