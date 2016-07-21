require_relative 'application_policy'

module Tint
	class FilePolicy < Tint::ApplicationPolicy
		def update?
			!!user
		end

		def destroy?
			!!user
		end
	end
end
