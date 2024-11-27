local mq = require('mq')
local spells = require('spells')
local mychar = require('mychar')
local co = require('co')
require('actions.s_memorize')


local gembot = {}


--
-- Globals
--

local actionqueue = {}

local State = {}
local Config = {}


--
-- Functions
--

local function log(msg)
	print('(gembot) ' .. msg)
end

local function do_memorize()
	local gems = Config.SpellBar.Gems()
	for gem, spell_key in pairs(gems) do
		--print(gem)
		if spell_key ~= 'OPEN' then
			local castable = Config.Spells.Spell(spell_key)
			if castable.Error == nil then
				if mq.TLO.Me.Gem(gem).Name() ~= castable.Name then
					actionqueue.AddUnique(
						ScpMemorize(
							castable.Name,
							'gem' .. gem,
							false,
							99
						)
					)
				end
			else
				log(castable.Error)
			end
		end
	end
end


--
-- Init
--

function gembot.Init(state, cfg, aq)
	State = state
	Config = cfg
	actionqueue = aq
end


---
--- Main Loop
---

function gembot.Run()
	log('Up and running')
	while true do
		if State.Mode ~= 1 and not mychar.InCombat() then
			do_memorize()
		end

		co.yield()
	end
end

return gembot