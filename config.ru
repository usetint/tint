if !ENV["RACK_ENV"] || ENV["RACK_ENV"] == "development"
	require "awesome_print"
	require "dotenv"
	require "pry"

	Dotenv.load
end

require_relative "app/app"

run Tint::App.new
