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

function str.Split(s, sSeparator, nMax, bRegexp)
	if s == nil then return {} end
	assert(sSeparator ~= '')
	assert(nMax == nil or nMax >= 1)

	local aRecord = {}

	if string.len(s) > 0 then
    	local bPlain = not bRegexp
      	nMax = nMax or -1

      	local nField, nStart = 1, 1
      	local nFirst,nLast = string.find(s, sSeparator, nStart, bPlain)
      	while nFirst and nMax ~= 0 do
         	aRecord[nField] = string.sub(s, nStart, nFirst-1)
         	nField = nField+1
         	nStart = nLast+1
         	nFirst,nLast = string.find(s, sSeparator, nStart, bPlain)
         	nMax = nMax-1
      	end
      	aRecord[nField] = string.sub(s, nStart)
   	end

   	return aRecord
end

function str.IsEmpty(s)
	return s == nil or string.len(s) == 0
end

return str