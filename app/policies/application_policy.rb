module Tint
	class ApplicationPolicy
		attr_reader :user, :record

		def initialize(user, record)
			@user = user
			@record = record
		end

		def index?
			false
		end

		def show?
			false
		end

		def create?
			false
		end

		def new?
			create?
		end

		def update?
			false
		end

		def edit?
			update?
		end

		def destroy?
			false
		end

		class Scope
			attr_reader :user, :scope

			def initialize(user, scope)
				@user = user
				@scope = scope
			end

			def resolve
				scope
			end
		end

	protected

		def matches_record_and_role(record, role)
			user && record.users.any? do |u|
				u[:role] == role && u[:user_id] == user.user_id
			end
		end
	end
end
