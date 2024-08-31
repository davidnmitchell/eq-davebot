local mq = require('mq')
local str = require('str')

local common = {}

function common.TableHasValue(T, value)
	for i=1,#T do
		if T[i] == value then
			return true
		end
	end
	return false
end

function common.TableIndexOf(T, value)
	for i=1,#T do
		if T[i] == value then return i end
	end
	return -1
end

function common.TableAsCsv(T)
	local s = ''
	for i=1,#T do
		if i == 1 then
			s = T[i]
		else
			s = s .. ',' .. T[i]
		end
	end
	return s
end

function common.TableLength(T)
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

function common.TableValueToBooleanOrDefault(t, key, default)
	if t[key] == nil then
		t[key] = default
	else
		t[key] = t[key] == 'TRUE'
	end	
end

function common.PrintTableKeys(T)
	for k,v in pairs(T) do print(k) end
end

function common.PrintTable(T)
	for i,v in pairs(T) do print(i .. '=' .. v) end
end

function common.PrintArray(A)
	for i,v in ipairs(A) do print(i .. '=' .. v) end
end

return common