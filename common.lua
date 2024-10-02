local mq = require('mq')
local str = require('str')

local common = {}

function common.TimeIt(func, ...)
	local start = mq.gettime()
	func(...)
	print(mq.gettime() - start)
end

function common.ArrayHasValue(T, value)
	for _, v in ipairs(T) do
		if value == v then
			return true
		end
	end
	return false
end

function common.MapHasKey(T, key)
	for k,_ in pairs(T) do
		if k == key then
			return true
		end
	end
	return false
end

function common.MapHasValue(T, value)
	for _, v in pairs(T) do
		if value == v then
			return true
		end
	end
	return false
end

function common.TableKeys(T)
	local keys = {}
	local i = 0
	for k,_ in pairs(T) do
		i = i + 1
		keys[i] =  k
	end
	return keys
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

function common.CopyAndOverlay(...)
    local res = {}
	local args = { ... }
	for i, table in ipairs(args) do
		for k, v in pairs(table) do
			res[k] = v
		end
    end
    return res
end


function common.PrintTableKeys(T)
	for k,v in pairs(T) do print(k) end
end

function common.PrintTable(T)
	for i,v in pairs(T) do print(tostring(i) .. '=' .. tostring(v)) end
end

function common.PrintArray(A)
	for i,v in ipairs(A) do print(i .. '=' .. v) end
end

return common