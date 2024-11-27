local mq = require('mq')

local sub = string.sub
local gsub = string.gsub
local find = string.find
local len = string.len
local gmatch = string.gmatch
local format = string.format


local str = {}

function str.AsNumber(s, default)
	local num = default
	if s then num = tonumber(s) end
	return num
end

function str.Trim(s)
	return gsub(s, "^%s*(.-)%s*$", "%1")
end

-- function str.Split(s, sep)
-- 	local res = {}

-- 	local start2 = mq.gettime()
-- 	for i = 1, 1000000 do
-- 		res = str.Split2(s, sep)
-- 	end
-- 	local elapsed2 = mq.gettime() - start2

-- 	local start1 = mq.gettime()
-- 	for i = 1, 1000000 do
-- 		res = str.Split1(s, sep)
-- 	end
-- 	local elapsed1 = mq.gettime() - start1

-- 	print('s: ' .. s .. ' ; sep: ' .. sep)
-- 	print('1: ' .. elapsed1 .. ' ; 2: ' .. elapsed2)

-- 	return res
-- end

function str.Split(s, sep)
	--print('s: ' .. s .. ' ; sep: ' .. sep)
	local result = { }
	if #s == 0 then return result end

	local idx = 1
	local from  = 1
	local delim_from, delim_to = find(s, sep, from)
	while delim_from do
		result[idx]          = sub(s, from, delim_from - 1)
		idx                  = idx + 1
		from                 = delim_to + 1
		delim_from, delim_to = find(s, sep, from)
	end
	local part = sub(s, from)
	if #part > 0 then
		result[idx] = part
	end
	return result
end

-- function str.Split2(s, sep)
-- 	local result = {}
-- 	if #s == 0 then return result end

-- 	local idx = 1
-- 	local regex = format("([^%s]+)", sep)
-- 	for each in gmatch(s, regex) do
-- 		result[idx] = each
-- 		idx = idx + 1
-- 	end
-- 	return result
-- end

function str.IsEmpty(s)
	return s == nil or len(s) == 0
end

function str.Insert(s1, s2, pos)
	return sub(s1, 1, pos) .. s2 .. sub(s1, pos + 1)
end

function str.StartsWith(s, start)
	return sub(s, 1, #start) == start
end

function str.EndsWith(s, ending)
	return ending == "" or sub(s, -#ending) == ending
end

function str.Join(arr, sep, start)
	sep = sep or ''
	start = start or 1
	local joined = arr[start] or ''
	local size = #arr
	for i = start + 1, size do
		joined = joined .. sep .. arr[i]
    end
	return joined
end

function str.FirstToUpper(s)
    return gsub(s, "^%l", string.upper)
end

return str
