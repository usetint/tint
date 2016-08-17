require "json"
require "securerandom"
require "shellwords"

module Tint
	class LocalJob
		attr_reader :site, :status

		def initialize(site)
			@site = site
		end

		def job_id
			"local_job"
		end

		def self.get(job_id)
			LocalJob.new(
				Tint::Site.new(
					site_id: (job_id || 1).to_i,
					user_id: 1,
					remote: "file://#{Pathname.new(ENV['SITE_PATH']).realpath}",
					cache_path: Pathname.new(ENV['SITE_PATH']).realpath,
					deploy_path: Pathname.new(ENV['PREFIX']).realpath,
					cloned: true,
					fn: "Local Site"
				)
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
