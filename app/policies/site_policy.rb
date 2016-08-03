require_relative 'application_policy'

module Tint
	class SitePolicy < Tint::ApplicationPolicy
		def index?
			return !!user if record == Tint::Site
			user && user[:user_id] == record.user_id
		end

		def create?
			!!user
		end
	end
end
