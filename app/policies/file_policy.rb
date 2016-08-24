require_relative 'application_policy'

module Tint
	class FilePolicy < Tint::ApplicationPolicy
		def show?
			user && user.user_id == record.user_id
		end

		def update?
			user && user.user_id == record.user_id
		end

		def destroy?
			user && user.user_id == record.user_id
		end
	end
end
