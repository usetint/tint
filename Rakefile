require 'rake/testtask'

Rake::TestTask.new do |t|
	t.pattern = "test/**/*_test.rb"
end

task :environment do
	begin
		require("dotenv")
		Dotenv.load
	rescue LoadError
	end
end

namespace :db do
	desc "Create a new migration"
	task :migration, [:name] => [:environment]  do |_t, args|
		path = "migrations/#{Time.now.to_i}_#{args[:name]}.rb"
		File.open(path, "w") do |file|
			file.write %{Sequel.migration do
	change do
	end
end}
		end
	end

	desc "Run migrations"
	task :migrate, [:version] => [:environment] do |_t, args|
		require "sequel"

		Sequel.extension :migration
		db = Sequel.connect(ENV.fetch("DATABASE_URL"))
		if args[:version]
			puts "Migrating to version #{args[:version]}"
			Sequel::Migrator.run(db, "migrations", target: args[:version].to_i)
		else
			puts "Migrating to latest"
			Sequel::Migrator.run(db, "migrations")
		end
	end

	desc "Open a console with the DB already required"
	task :console => [:environment] do
		raise "No DB in local mode" if ENV["SITE_PATH"]

		require "irb"
		require "irb/completion"
		require_relative "app/db"

		ARGV.clear
		IRB.start
	end
end

task default: [:test]
