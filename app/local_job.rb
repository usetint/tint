require "json"
require "securerandom"
require "shellwords"

require_relative "db"

module Tint
	class LocalJob
		attr_reader :job_id, :site, :status

		def initialize(site, job_id=nil)
			@site = site
			@job_id = job_id || SecureRandom.uuid
		end

		def self.local_site(site_id=nil)
			Tint::Site.new(
				site_id: (site_id || 1).to_i,
				user_id: 1,
				remote: "file://#{Pathname.new(ENV.fetch('SITE_PATH')).realpath}",
				cache_path: Pathname.new(ENV.fetch('SITE_PATH')).realpath,
				deploy_path: Pathname.new(ENV.fetch('PREFIX')).realpath,
				cloned: true,
				fn: "Local Site"
			)
		end

		def self.get(job_id)
			LocalJob.new(
				if Tint.db
					Tint::Site.new(Tint.db[:jobs].join(:sites, site_id: :site_id)[job_id: job_id])
				else
					local_site
				end,
				job_id
			)
		end

		def enqueue!
			if status
				raise "This job is already in the queue."
			end

			@status = :created

			Tempfile.open("tint-build") do |tmp|
				tmp.puts(Tint.build_script(
					job_id,
					site.to_h[:site_id],
					site.remote,
					Tint.token(job_id)
				))
				tmp.flush
				if system("env -i - PATH=\"#{ENV['PATH']}\" GEM_PATH=\"#{ENV['GEM_PATH']}\" /bin/sh #{Shellwords.escape(tmp.path)}")
					@status = :passed
				else
					@status = :errored
				end
			end
		end
	end
end
