local mq = require('mq')
local co = require('co')
local target = require('target')


Cast = {}
Cast.__index = Cast

function Cast:new(spell_name, preferred_gem, target_id, message, min_mana_required, skip_if_target_hp_below, max_tries, priority)
	local obj = {}
	setmetatable(obj, Cast)

	obj._spell_name = spell_name
	obj._preferred_gem = preferred_gem or '0'
	if tonumber(obj._preferred_gem) then obj._preferred_gem = 'gem' .. obj._preferred_gem end
	obj._target_id = tonumber(target_id) or 0
	obj._message = message or ''
	obj._min_mana_required = tonumber(min_mana_required) or 0
	obj._skip_if_target_hp_below = tonumber(skip_if_target_hp_below) or 0
	obj._max_tries = tonumber(max_tries) or 1
	obj._priority = tonumber(priority) or 99
	obj._added_at=mq.gettime()

	return obj
end

function Cast:_log(msg)
	print('(cast) ' .. msg)
end

function Cast:_announce(msg)
	mq.cmd('/g ' .. msg)
end

function Cast:_face_target()
	mq.cmd('/target id ' .. self._target_id)
	co.delay(500, function() return mq.TLO.Target.ID() == self._target_id end)
	mq.cmd('/face id ' .. self._target_id)
end

function Cast:Execute()
	self:_announce(self._message)

	if self._target_id > 0 and self._target_id ~= mq.TLO.Me.ID() then
		self:_face_target()
	end

	local cmd = '/casting "' .. self._spell_name .. '" ' .. self._preferred_gem .. ' -maxtries|' .. self._max_tries .. ' -invis'
	if self._target_id > 0 then
		cmd = cmd .. ' -targetid|' .. self._target_id
		local target_name = mq.TLO.Spawn(self._target_id).Name() or "NIL"
		self:_log('Casting ' .. self._spell_name .. ' on ' .. target_name)
	else
		self:_log('Casting ' .. self._spell_name)
	end
	mq.cmd(cmd)
	--print(cmd)
	--co.delay(1000)
end

function Cast:SpellName()
	return self._spell_name
end

function Cast:Priority()
	return self._priority
end

function Cast:Message()
	return self._message
end

function Cast:HasTarget()
	return self._target_id > 0
end

function Cast:TargetIsAlive()
	return target.IsAlive(self._target_id)
end

function Cast:InRange()
	local range = mq.TLO.Spell(self._spell_name).Range() or 200
	local distance = mq.TLO.Spawn(self._target_id).Distance() or 0

	return range == 0 or distance <= range
end

function Cast:LineOfSight()
	return mq.TLO.Spawn(self._target_id).LineOfSight() or false
end

function Cast:IsInvisibilityOnMe()
	return self._spell_name == 'Invisibility' and self._target_id == mq.TLO.Me.ID()
end

function Cast:TargetHPsAreTooLow()
	local target_hp_pct = mq.TLO.Spawn(self._target_id).PctHPs() or -1
	return target_hp_pct < self._skip_if_target_hp_below
end

function Cast:IHaveEnoughMana()
	return mq.TLO.Me.PctMana() >= self._min_mana_required
end

function Cast:TargetName()
	return mq.TLO.Spawn(self._target_id).Name() or '(none)'
end

function Cast:Skip(reason)
	self:_announce('Skipping "' .. self._message .. '" because ' .. reason)
end

function Cast:IsSame(cast)
	return cast ~= nil and cast._spell_name == self._spell_name and cast._target_id == self._target_id
end