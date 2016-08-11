if !ENV["RACK_ENV"] || ENV["RACK_ENV"] == "development"
	require "awesome_print"
	require "dotenv"
	require "pry"

	Dotenv.load
end

require_relative "app/app"
require_relative "app/controllers/file"

run Rack::Cascade.new([Tint::App, Tint::Controllers::File])
