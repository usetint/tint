module Tint
	module PathHelpers
		def self.ensure(path)
			path = Pathname.new(path)
			path.mkpath
			path.realpath
		end
	end
end
