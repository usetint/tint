if !ENV["RACK_ENV"] || ENV["RACK_ENV"] == "development"
	require "awesome_print"
	require "dotenv"
	require "pry"

	Dotenv.load
end

require "sequel"

require_relative "app/app"
require_relative "app/controllers/auth"
require_relative "app/controllers/site"
require_relative "app/controllers/file"

ENV["GIT_COMMITTER_NAME"] = "Tint"
ENV["GIT_COMMITTER_EMAIL"] = "commit@usetint.com"

module Tint
	DB = Sequel.connect(ENV.fetch("DATABASE_URL")) unless ENV['SITE_PATH']
end

run Rack::Cascade.new([
	Tint::App,
	Tint::Controllers::Auth,
	Tint::Controllers::Site,
	Tint::Controllers::File
])
