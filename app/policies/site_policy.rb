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

		def update?
			user && user[:user_id] == record.user_id
		end

		class Scope < Scope
			def initialize(user, scope)
				super(user, scope == Tint::Site ? DB[:sites] : scope)
			end

			def resolve
				scope.where(user_id: user[:user_id]).map do |site_rec|
					Tint::Site.new(site_rec)
				end
			end
		end
	end
end
