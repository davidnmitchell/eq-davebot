local mq = require('mq')
local str = require('str')

local common = {}


IniFilename = 'Bot_' .. mq.TLO.Me.CleanName() .. '.ini'

function common.trim(s)
   return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function common.split(str, sSeparator, nMax, bRegexp)
	if str == nil then return {} end
   assert(sSeparator ~= '')
   assert(nMax == nil or nMax >= 1)

   local aRecord = {}

   if string.len(str) > 0 then
      local bPlain = not bRegexp
      nMax = nMax or -1

      local nField, nStart = 1, 1
      local nFirst,nLast = string.find(str, sSeparator, nStart, bPlain)
      while nFirst and nMax ~= 0 do
         aRecord[nField] = string.sub(str, nStart, nFirst-1)
         nField = nField+1
         nStart = nLast+1
         nFirst,nLast = string.find(str, sSeparator, nStart, bPlain)
         nMax = nMax-1
      end
      aRecord[nField] = string.sub(str, nStart)
   end

   return aRecord
end

function common.emptyStr(str)
	return str == nil or string.len(str) == 0
end

function common.EmptyString(str)
	return str == nil or string.len(str) == 0
end

function common.empty(filename, section, key)
	return common.emptyStr(mq.TLO.Ini(filename, section, key)())
end

function common.LoadFromIniWithDefault(filename, section, key, default)
	if not common.empty(filename, section, key) then
		return mq.TLO.Ini(filename, section, key)()
	end
	return default
end

function common.ConfigString(section, key, default)
	return common.LoadFromIniWithDefault(IniFilename, section, key, default)
end

function common.ConfigNumber(section, key, default)
	return tonumber(common.LoadFromIniWithDefault(IniFilename, section, key, default))
end

function common.ConfigBoolean(section, key, default)
	local v = common.LoadFromIniWithDefault(IniFilename, section, key, default)
	if type(v) == 'string' then
		return v == 'TRUE'
	end
	return v
end

function common.tableLength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

function common.TableValueToNumberOrDefault(t, key, default)
	if t[key] == nil then
		t[key] = default
	else
		t[key] = tonumber(t[key])
	end	
end

function common.print_table(T)
	for i,v in pairs(T) do print(i .. '=' .. v) end
end

function common.printArray(A)
	for i,v in ipairs(A) do print(i .. '=' .. v) end
end

function common.is_script_running(name)
	local status = mq.TLO.Lua.Script(name).Status()
	return status ~= nil and status == 'RUNNING'
end

function common.run_script_if_not_running(name)
	if not common.is_script_running(name) then
		mq.cmd('/lua run ' .. name)
	end
end

function common.runScriptAndBlock(name)
	mq.cmd('/lua run ' .. name)
	mq.delay(50)
	while mq.TLO.Lua.Script(name).Status() == 'RUNNING' do
		mq.delay(50)
	end
end

function spellSortingFunction(spell1, spell2)
	return spell1.level > spell2.level
end

function common.findspell(category, subcategory, target, depth)
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
	table.sort(found, spellSortingFunction)
	if #found > 0 then
		return table.remove(found, dpth).spell
	else
		return nil
	end
end

function common.ReferenceSpell(str)
	if str and string.find(str, ',') ~= nil then
		local parts = common.split(str, ',')
		if #parts == 3 then
			return common.findspell(parts[1], parts[2], parts[3])
		else
			return common.findspell(parts[1], parts[2], parts[3], parts[4])
		end
	end
	return str
end

function common.readyToCast()
	return not mq.TLO.Me.Moving() and mq.TLO.Cast.Status() == 'I'
end

function common.casting()
	local status = mq.TLO.Cast.Status()
	return status ~= 'C'
end

function common.castAndBlock(spell, gem, targetid, maxtries)
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

function common.memorizeAndBlock(spell, gem_number)
	local cmd = '/memorize "' .. spell .. '" gem' .. gem_number
	print(cmd)
	mq.cmd(cmd)
	while not mq.TLO.Cast.Ready(gem_number)() do
		print(mq.TLO.Cast.Ready(gem_number)())
		mq.delay(100)
		--mq.cmd('/memorize "' .. spell .. '" gem' .. gem_number)
	end
	while mq.TLO.Cast.Status() ~= 'I' do
		mq.delay(10)
	end
end

function common.BardCast(spell, gem_number, target_id)
	mq.cmd('/echo NOTIFY BCACTIVE')
	mq.delay(250)
	mq.cmd('/twist clear')
	mq.delay(500)
	common.memorizeAndBlock(spell, gem_number)
	mq.cmd('/cast ' .. gem_number)
	mq.delay(mq.TLO.Spell(spell).CastTime.Seconds() * 1000)
	mq.cmd('/echo NOTIFY BCINACTIVE')
end

function common.peerById(id)
	for i=1,mq.TLO.DanNet.PeerCount() do
		local peer = mq.TLO.DanNet.Peers(i)()
		local remoteid = common.query(peer, 'Me.ID')
		if tonumber(id) == tonumber(remoteid) then
			return peer
		end
	end
	return nil
end

function common.peerByPetId(id)
	for i=1,mq.TLO.DanNet.PeerCount() do
		local peer = mq.TLO.DanNet.Peers(i)()
		local remoteid = tonumber(common.query(peer, 'Pet.ID'))
		if id == remoteid then
			return peer
		end
	end
	return nil
end


function common.query(peer, query, timeout)
    mq.cmdf('/dquery %s -q "%s"', peer, query)
    mq.delay(timeout or 1000)
    return mq.TLO.DanNet(peer).Q(query)()
end

function common.observe(peer, query, timeout)
    if not mq.TLO.DanNet(peer).OSet(query)() then
        mq.cmdf('/dobserve %s -q "%s"', peer, query)
    end
    mq.delay(timeout or 1000, function() return mq.TLO.DanNet(peer).O(query).Received() > 0 end)
    return mq.TLO.DanNet(peer).O(query)()
end

function common.unobserve(peer, query)
    mq.cmdf('/dobserve %s -q "%s" -drop', peer, query)
end



function common.IsGroupInCombat()
	return mq.TLO.Me.XTarget() > 0
	-- for i=1,mq.TLO.DanNet.PeerCount() do
		-- local peer = mq.TLO.DanNet.Peers(i)()
		-- local combat = common.query(peer, 'Me.Combat')
		-- if combat then
			-- return true
		-- end
	-- end
	-- return false
end

function common.IsIdInGroup(id)
	if mq.TLO.Me.ID() == id then
		return true
	end
	for i=1,mq.TLO.Group.Members() do
		if mq.TLO.Group.Member(i).ID() == id then
			return true
		end
	end
	return false
end

function common.TargetIsAlive(target_id)
	local target_state = mq.TLO.Spawn(target_id).State()
	local pct_hps = mq.TLO.Spawn(target_id).PctHPs()

	return target_state ~= nil and target_state ~= 'DEAD' and pct_hps ~= nil and pct_hps > 0
end

return common