require_relative 'application_policy'

module Tint
	class DirectoryPolicy < Tint::ApplicationPolicy
		def update?
			!!user
		end
	end
end
