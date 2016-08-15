require "sequel"

module Tint
	DB = Sequel.connect(ENV.fetch("DATABASE_URL")) unless ENV['SITE_PATH']
end
