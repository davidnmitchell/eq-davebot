local mq = require('mq')
local str = require('str')

local common = {}


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

function common.PrintTable(T)
	for i,v in pairs(T) do print(i .. '=' .. v) end
end

function common.PrintArray(A)
	for i,v in ipairs(A) do print(i .. '=' .. v) end
end

return common