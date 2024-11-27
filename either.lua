
function Either()
	local self = {}
	self.__type__ = 'Either'

	self.IsLeft = false
	self.IsRight = false

	self.Left = 0
	self.Right = 0

	return self
end

function Right(value)
	local self = Either()

	self.IsRight = true
	self.Right = value

	return self
end

function Left(value)
	local self = Either()

	self.IsLeft = true
	self.Left = value

	return self
end

