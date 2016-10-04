require_relative 'application_policy'

module Tint
	class SitePolicy < Tint::ApplicationPolicy
		def index?
			return !!user if record == Tint::Site
			user && record.users.any? { |u| u[:user_id] == user.user_id }
		end

		def create?
			!!user
		end

		def update?
			user && record.users.any? { |u| u[:user_id] == user.user_id }
		end

		def manage_users?
			user && record.users.any? do |u|
				u[:role] == "owner" && u[:user_id] == user.user_id
			end
		end

		def accept_invitation?
			!!user
		end

		def destroy?
			update?
		end

		class Scope < Scope
			def initialize(user, scope)
				super(user, scope == Tint::Site ? Tint.db[:sites] : scope)
			end

			def resolve
				scope.join(:site_users, site_id: :site_id).
				      where(user_id: user.user_id).map do |site_rec|
					# This site does not have users set, but
					# that isn't an issue in any current use and saves time for now
					Tint::Site.new(site_rec)
				end
			end
		end
	end
end
