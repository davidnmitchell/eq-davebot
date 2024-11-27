
local array = {}

function array.HasValue(T, value)
	local size = #T
	for i=1, size do
		if T[i] == value then return true end
	end
	return false
end

function array.IndexOf(T, value)
	local size = #T
	for i=1, size do
		if T[i] == value then return i end
	end
	return -1
end

function array.Any(T, func)
	local size = #T
	for i=1, size do
		if func(T[i]) then return true end
	end
	return false
end

function array.None(T, func)
	local size = #T
	for i=1, size do
		if func(T[i]) then return false end
	end
	return true
end

function array.All(T, func)
	local size = #T
	for i=1, size do
		if not func(T[i]) then return false end
	end
	return true
end

function array.FirstOrNil(T, func)
	local size = #T
	for i=1, size do
		if func(T[i]) then return T[i] end
	end
	return nil
end

function array.Mapped(T, func)
	local mapped = {}
	local size = #T
	for i=1, size do
		mapped[i] =  func(T[i])
	end
	return mapped
end

function array.Filtered(T, func)
	local filtered = {}
	local size = #T
	for i=1, size do
		local e = T[i]
		if func(e) then
			filtered[#filtered + 1] = e
		end
	end
	return filtered
end

function array.Equal(T1, T2)
	if #T1 ~= #T2 then
		return false
	else
		local size = #T1
		for i = 1, size do
			if T1[i] ~= T2[i] then
				return false
			end
		end
		return true
	end
end

function array.AsCsv(T)
	local s = ''
	local size = #T
	for i=1, size do
		if i == 1 then
			s = T[i]
		else
			s = s .. ',' .. T[i]
		end
	end
	return s
end

function array.Print(T)
	local size = #T
	for i=1, size do
		print(i .. '=' .. tostring(T[i]))
	end
end

return array