require_relative 'application_policy'

module Tint
	class FilePolicy < Tint::ApplicationPolicy
		def show?
			user && record.users.any? { |u| u[:user_id] == user.user_id }
		end

		def update?
			user && record.users.any? { |u| u[:user_id] == user.user_id }
		end

		def destroy?
			user && record.users.any? { |u| u[:user_id] == user.user_id }
		end
	end
end
