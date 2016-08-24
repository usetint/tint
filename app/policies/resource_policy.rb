module Tint
	class ResourcePolicy < ApplicationPolicy
		def index?
			user && user.user_id == record.user_id
		end
	end
end
