local mq = require('mq')
local str = require('str')
local common = require('common')

local spells = {}


local MyName = mq.TLO.Me.Name()
local MyClass = mq.TLO.Me.Class.Name()
local AmBard = MyClass == 'Bard'

local History = {}


local function in_history(spell, target_id)
	-- print('-----History-----')
	-- for i, sinfo in ipairs(History) do
		-- local hspell = sinfo.spell
		-- local htarget_id = sinfo.targetid
		-- if not htarget_id then htarget_id = 'NIL' end
		-- local htimestamp = sinfo.timestamp
		-- print(i .. ':' .. hspell .. ':' .. htarget_id .. ':' .. htimestamp - (os.clock() - 10))
	-- end

	for i, sinfo in ipairs(History) do
		if sinfo.timestamp < os.clock() - 3 then
			table.remove(History, i)
		end	
	end

	for i, sinfo in ipairs(History) do
		if sinfo.spell == spell and sinfo.targetid == target_id then
			return true
		end
	end
	return false
end


function spells.QueueSpell(spell, gem, target_id, msg, min_mana_pct, min_target_hp_pct, max_tries, priority)
	table.insert(History, { spell=spell, targetid=target_id, timestamp=os.clock() })
	if not AmBard then
		mq.cmd('/echo COMMAND CASTQUEUEADD |' .. spell .. '|' .. gem .. '|' .. target_id .. '|' .. msg .. '|' .. min_mana_pct .. '|' .. min_target_hp_pct .. '|' .. max_tries .. '|' .. priority)
	else
		spells.BardCast(spell, gem, target_id)
	end
end

function spells.QueueSpellIfNotQueued(spell, gem, target_id, msg, min_mana_pct, min_target_hp_pct, max_tries, priority)
	if not in_history(spell, target_id) then
		table.insert(History, { spell=spell, targetid=target_id, timestamp=os.clock() })

		if not AmBard then
			mq.cmd('/echo COMMAND CASTQUEUEADDUNIQUE |' .. spell .. '|' .. gem .. '|' .. target_id .. '|' .. msg .. '|' .. min_mana_pct .. '|' .. min_target_hp_pct .. '|' .. max_tries .. '|' .. priority)
		else
			if type(gem) == 'string' then
				if gem:find('^gem') ~= nil then
					spells.BardCast(spell, tonumber(gem:sub(4, gem:len())), target_id)
				else
					print('Unexpected string for gem: ' .. gem)
				end
			else
				spells.BardCast(spell, gem, target_id)
			end
		end
	end
end

function spells.WipeQueue()
	while #History > 0 do table.remove(History) end
	mq.cmd('/echo COMMAND CASTQUEUEREMOVEALL')
end

function spells.FindSpell(category, subcategory, target, depth)
    local i = 1
    local found = {}
    local done = false
	local dpth = 1
	if depth ~= nil then dpth = depth end

    while not done do
		local spell = mq.TLO.Me.Book(i)()
		if spell == nil then
			done = true
		else
			--if spell == 'Gift of Pure Thought' then
				--print(spell .. ':' .. mq.TLO.Me.Spell(spell).TargetType())
			--end
			if target == mq.TLO.Me.Spell(spell).TargetType() and category == mq.TLO.Me.Spell(spell).Category() and subcategory == mq.TLO.Me.Spell(spell).Subcategory() then
				table.insert(found, 1, {spell=spell, level = mq.TLO.Me.Spell(spell).Level()})
			end
			i = i + 1
		end
    end
	table.sort(
		found,
		function (spell1, spell2)
			return spell1.level > spell2.level
		end
	)
	if #found > 0 then
		return table.remove(found, dpth).spell
	else
		return nil
	end
end

function spells.ReferenceSpell(spell_or_csv)
	if spell_or_csv and spell_or_csv:find(',') ~= nil then
		local parts = str.Split(spell_or_csv, ',')
		if #parts == 3 then
			return spells.FindSpell(parts[1], parts[2], parts[3])
		else
			return spells.FindSpell(parts[1], parts[2], parts[3], parts[4])
		end
	end
	return spell_or_csv
end

function spells.CastAndBlock(spell, gem, targetid, maxtries)
	local tries = str.AsNumber(maxtries, 3)
	if targetid ~= nil then
		mq.cmd('/casting "' .. spell .. '" gem' .. gem .. ' -targetid|' .. targetid .. ' -maxtries|' .. tries)
	else
		mq.cmd('/casting "' .. spell .. '" gem' .. gem .. ' -maxtries|' .. tries)
	end
	while mq.TLO.Cast.Status() ~= 'I' do
		mq.delay(10)
	end
end

function spells.MemorizeAndBlock(spell, gem_number)
	local cmd = '/memorize "' .. spell .. '" gem' .. gem_number
	mq.cmd(cmd)
	while not mq.TLO.Cast.Ready(gem_number)() do
		mq.delay(100)
	end
	while mq.TLO.Cast.Status() ~= 'I' do
		mq.delay(10)
	end
end

function spells.BardCast(spell, gem_number, target_id)
	mq.cmd('/echo NOTIFY BCACTIVE')
	mq.delay(250)
	mq.cmd('/twist clear')
	mq.delay(500)
	spells.MemorizeAndBlock(spell, gem_number)
	if target_id then
		mq.cmd('/target id ' .. target_id)
		mq.delay(100)
	end
	mq.cmd('/cast ' .. gem_number)
	mq.delay(mq.TLO.Spell(spell).CastTime.Seconds() * 1000)
	mq.cmd('/echo NOTIFY BCINACTIVE')
end

return spells