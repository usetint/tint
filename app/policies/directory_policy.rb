require_relative 'application_policy'

module Tint
	class DirectoryPolicy < Tint::ApplicationPolicy
		def index?
			user && user.user_id == record.user_id
		end

		def update?
			user && user.user_id == record.user_id
		end
	end
end
