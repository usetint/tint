require "sequel"

module Tint
	def self.db
		@@db ||= Sequel.connect(ENV.fetch("DATABASE_URL")) unless ENV['SITE_PATH']
	end
end
