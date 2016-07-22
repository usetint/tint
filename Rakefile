require 'rake/testtask'

Rake::TestTask.new do |t|
	t.pattern = "test/**/*_test.rb"
end

namespace :db do
	desc "Create a new migration"
	task :migration, [:name]  do |task, args|
		path = "migrations/#{Time.now.to_i}_#{args[:name]}.rb"
		File.open(path, "w") do |file|
			file.write %{Sequel.migration do
	change do
	end
end}
		end
	end

	desc "Run migrations"
	task :migrate, [:version] do |t, args|
		require "sequel"
		if !ENV["RACK_ENV"] || ENV["RACK_ENV"] == "development"
			require "dotenv"
			Dotenv.load
		end

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
end

task default: [:test]
