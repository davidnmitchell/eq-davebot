local mq = require('mq')

local str = {}

function str.AsNumber(s, default)
	local num = default
	if s then num = tonumber(s) end
	return num
end

function str.Trim(s)
	return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function str.Split(s, sep)
	local result = {}
	local regex = ("([^%s]+)"):format(sep)
	for each in s:gmatch(regex) do
	   table.insert(result, each)
	end
	return result
end

function str.IsEmpty(s)
	return s == nil or string.len(s) == 0
end

function str.Insert(s1, s2, pos)
    return s1:sub(1,pos)..s2..s1:sub(pos+1)
end

function str.StartsWith(s, start)
	return s:sub(1, #start) == start
end

function str.EndsWith(s, ending)
	return ending == "" or s:sub(-#ending) == ending
end

function str.Join(arr, start)
	local s = arr[start] or ''
    for i = start+1, #arr, 1 do
		s = s .. ' ' .. arr[i]
    end
	return s
end

function str.FirstToUpper(s)
    return (s:gsub("^%l", string.upper))
end

return str
