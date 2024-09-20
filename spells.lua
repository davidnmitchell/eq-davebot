local mq = require('mq')
local co = require('co')
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

local function dbcq_queue_cmd(unique, spell, gem, target_id, msg, min_mana_pct, min_target_hp_pct, max_tries, priority)
	local cmd = '/dbcq queue -spell|' .. spell
	if unique then cmd = cmd .. ' -unique|TRUE' end
	if gem then cmd = cmd .. ' -gem|' .. gem end
	if target_id then cmd = cmd .. ' -target_id|' .. target_id end
	if msg then cmd = cmd .. ' -message|' .. msg end
	if min_mana_pct then cmd = cmd .. ' -min_mana|' .. min_mana_pct end
	if min_target_hp_pct then cmd = cmd .. ' -min_target_hps|' .. min_target_hp_pct end
	if max_tries then cmd = cmd .. ' -max_tries|' .. max_tries end
	if priority then cmd = cmd .. ' -priority|' .. priority end
	return cmd
end

function spells.QueueSpell(spell, gem, target_id, msg, min_mana_pct, min_target_hp_pct, max_tries, priority)
	table.insert(History, { spell=spell, targetid=target_id, timestamp=os.clock() })
	if not AmBard then
		local cmd = dbcq_queue_cmd(false, spell, gem, target_id, msg, min_mana_pct, min_target_hp_pct, max_tries, priority)
		mq.cmd(cmd)
	else
		spells.BardCast(spell, gem, target_id)
	end
end

function spells.QueueSpellIfNotQueued(spell, gem, target_id, msg, min_mana_pct, min_target_hp_pct, max_tries, priority)
	if not in_history(spell, target_id) then
		table.insert(History, { spell=spell, targetid=target_id, timestamp=os.clock() })

		if not AmBard then
			local cmd = dbcq_queue_cmd(true, spell, gem, target_id, msg, min_mana_pct, min_target_hp_pct, max_tries, priority)
			mq.cmd(cmd)
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
	mq.cmd('/dbcq removeall')
end

function spells.KnownSpellCount()
    local i = 1
    while mq.TLO.Me.Book(i)() do
        i = i + 1
    end
    return i-1
end

function spells.DumpSpellBook(ini, section_name)
	local i = 1
	local done = false
	local spell_book = {}

	while not done do
		local spell = mq.TLO.Me.Book(i)()
		if spell == nil then
			done = true
		else
			local name = spell
			local category = mq.TLO.Spell(spell).Category()
			local subcategory = mq.TLO.Spell(spell).Subcategory()
			local type = mq.TLO.Spell(spell).TargetType()
			local level = mq.TLO.Spell(spell).Level()

			local parts = str.Split(name, ' ')
			local key = string.lower(parts[#parts]):gsub('`', '') .. level

			table.insert(spell_book, 1, {key=key, name=name, level=level, category=category, subcategory=subcategory, type=type})
			i = i + 1
		end
	end

	table.sort(
		spell_book,
		function (spell1, spell2)
			if spell1.level == spell2.level then
				return spell1.name < spell2.name
			end
			return spell1.level < spell2.level
		end
	)

	local section = ini:Section(section_name)
	for idx,spell in ipairs(spell_book) do
		local name_pad = 18 - string.len(spell.key)
		local comment_pad = 35 - string.len(spell.name)

		local name = spell.name
		local comment = ';' .. spell.category .. ',' .. spell.subcategory .. ',' .. spell.type

		for j=1,name_pad do name = str.Insert(name, ' ', 0) end
		for j=1,comment_pad do comment = str.Insert(comment, ' ', 0) end

		section:WriteString(spell.key, name .. comment)
	end

	print('Wrote ' .. (i-1) .. ' spells to ini')
end

function spells.FindSpell(category, subcategory, target, depth)
    local i = 1
    local found = {}
    local done = false
	local dpth = depth or 1

    while not done do
		local spell = mq.TLO.Me.Book(i)()
		if spell == nil then
			done = true
		else
			--if spell == 'Gift of Pure Thought' then
				--print(spell .. ':' .. mq.TLO.Me.Spell(spell).TargetType())
			--end
			if target == mq.TLO.Spell(spell).TargetType() and category == mq.TLO.Spell(spell).Category() and subcategory == mq.TLO.Spell(spell).Subcategory() then
				table.insert(found, 1, {spell=spell, level = mq.TLO.Spell(spell).Level()})
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
		return ''
	end
end

function spells.ReferenceSpell(spell_or_csv)
	if spell_or_csv and spell_or_csv:find(',') ~= nil then
		local parts = str.Split(spell_or_csv, ',')
		if parts[1]:lower() == 'item' then
			return parts[2]
		elseif parts[1]:lower() == 'aa' then
			return parts[2]
		else
			if #parts == 3 then
				return spells.FindSpell(parts[1], parts[2], parts[3])
			else
				return spells.FindSpell(parts[1], parts[2], parts[3], parts[4])
			end
		end
	end
	return spell_or_csv or ''
end

function spells.CastAndBlock(spell, gem, targetid, maxtries)
	local tries = str.AsNumber(maxtries, 3)
	if targetid ~= nil then
		mq.cmd('/casting "' .. spell .. '" gem' .. gem .. ' -targetid|' .. targetid .. ' -maxtries|' .. tries)
	else
		mq.cmd('/casting "' .. spell .. '" gem' .. gem .. ' -maxtries|' .. tries)
	end
	---@diagnostic disable-next-line: undefined-field
	while mq.TLO.Cast.Status() ~= 'I' do
		co.delay(50)
	end
end

function spells.MemorizeAndBlock(spell, gem_number)
	local cmd = '/memorize "' .. spell .. '" gem' .. gem_number
	mq.cmd(cmd)
	---@diagnostic disable-next-line: undefined-field
	while not mq.TLO.Cast.Ready(gem_number)() do
		mq.delay(100)
	end
	---@diagnostic disable-next-line: undefined-field
	while mq.TLO.Cast.Status() ~= 'I' do
		mq.delay(10)
	end
end

function spells.BardCast(spell, gem_number, target_id)
	---@diagnostic disable-next-line: undefined-field
	mq.TLO.DaveBot.States.BardCastIsActive()
	mq.delay(250)
	mq.cmd('/twist clear')
	mq.delay(500)
	spells.MemorizeAndBlock(spell, gem_number)
	if target_id then
		mq.cmd('/target id ' .. target_id)
		mq.delay(100)
	end
	mq.cmd('/cast ' .. gem_number)
	mq.delay((mq.TLO.Spell(spell).CastTime.Seconds() + 2) * 1000)
	---@diagnostic disable-next-line: undefined-field
	mq.TLO.DaveBot.States.BardCastIsInactive()
end

return spells