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
	local gems = Config:SpellBar():Gems()
	for gem, spell_key in pairs(gems) do
		if spell_key ~= 'OPEN' then
			local spell = Config:Spells():Spell(spell_key)
			if spell.Error == nil then
				if mq.TLO.Me.Gem(gem).Name() ~= spell.Name then
					actionqueue.AddUnique(
						ScpMemorize(
							spell.Name,
							'gem' .. gem,
							false,
							99
						)
					)
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
		if not mychar.InCombat() then
			do_memorize()
		end

		co.yield()
	end
end

return gembot