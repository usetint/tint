require_relative 'application_policy'

module Tint
	class DirectoryPolicy < Tint::ApplicationPolicy
		def index?
			user && record.users.any? { |u| u[:user_id] == user.user_id }
		end

		def update?
			user && record.users.any? { |u| u[:user_id] == user.user_id }
		end

		def mkdir?
			matches_record_and_role(record, "owner")
		end

		def rename?
			matches_record_and_role(record, "owner")
		end
	end
end
