if !ENV["RACK_ENV"] || ENV["RACK_ENV"] == "development"
	require "awesome_print"
	require "dotenv"
	require "pry"

	Dotenv.load
end

require "sequel"

require_relative "app/controllers/asset"
require_relative "app/controllers/auth"
require_relative "app/controllers/build"
require_relative "app/controllers/file"
require_relative "app/controllers/site"

ENV["GIT_COMMITTER_NAME"] = "Tint"
ENV["GIT_COMMITTER_EMAIL"] = "commit@usetint.com"

module Tint
	DB = Sequel.connect(ENV.fetch("DATABASE_URL")) unless ENV['SITE_PATH']
	BuildJob = ENV['TRAVIS_WORKER_BASE_DIR'] ? TravisJob : LocalJob
end

run Rack::Cascade.new([
	Tint::Controllers::Asset,
	Tint::Controllers::Auth,
	Tint::Controllers::Build,
	Tint::Controllers::File,
	Tint::Controllers::Site
])
