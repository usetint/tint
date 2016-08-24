module Tint
	class User
		attr_reader :fn, :email, :user_id

		def initialize(attributes)
			@fn = attributes[:fn]
			@email = attributes[:email]
			@user_id = attributes[:user_id]
		end
	end
end
