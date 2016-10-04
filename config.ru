if !ENV["RACK_ENV"] || ENV["RACK_ENV"] == "development"
	require "awesome_print"
	require "dotenv"
	require "pry"

	Dotenv.load
end

require "uri"

require_relative "app/db"
require_relative "app/controllers/asset"
require_relative "app/controllers/auth"
require_relative "app/controllers/build"
require_relative "app/controllers/file"
require_relative "app/controllers/site"

ENV["GIT_COMMITTER_NAME"] = "Tint"
ENV["GIT_COMMITTER_EMAIL"] = "commit@usetint.com"
ENV["GIT_SSH"] = Pathname.new(__FILE__).realpath.dirname.join("git_ssh").to_s

module Tint
	BuildJob = ENV['TRAVIS_WORKER_BASE_DIR'] ? TravisJob : LocalJob
	DOMAIN = ENV["APP_URL"] && URI(ENV["APP_URL"]).hostname.split(/\./).last(2).join(".")
end

run Rack::Cascade.new([
	Tint::Controllers::Asset,
	Tint::Controllers::Auth,
	Tint::Controllers::Build,
	Tint::Controllers::File,
	Tint::Controllers::Site
])
