require_relative 'application_policy'

module Tint
	class DirectoryPolicy < Tint::ApplicationPolicy
		def index?
			user && record.users.any? { |u| u[:user_id] == user.user_id }
		end

		def update?
			user && record.users.any? { |u| u[:user_id] == user.user_id }
		end
	end
end
