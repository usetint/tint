require "json"
require "pathname"
require "securerandom"

require_relative "db"
require_relative "path_helpers"

module Tint
	class TravisJob
		attr_reader :job_id, :site, :status

		def initialize(site_or_payload, job_id=SecureRandom.uuid, status=nil)
			if site_or_payload.is_a?(Tint::Site)
				@site = site_or_payload
			else
				@payload = site_or_payload
				@site = Tint::Site.new(Tint.db[:sites][site_id: @payload['site']['site_id']])
			end

			@job_id = job_id
			@status = status
		end

		def self.get(job_id)
			{
				created: queue_dir.join("10-created.d"),
				received: queue_dir.join("30-received.d"),
				started: queue_dir.join("50-started.d"),
				finished: queue_dir.join("70-finished.d")
			}.each do |status, dir|
				if (path = dir.join("#{job_id}.json")).exist?
					if dir.join("#{job_id}.state").exist?
						status = dir.join("#{job_id}.state").open.read.strip.to_sym
					end

					return TravisJob.new(JSON.parse(path.open.read), job_id, status)
				end
			end
		end

		def log_path
			queue_dir.join("log").join("#{job_id}.log")
		end

		def enqueue!
			if status
				raise "This job is already in the queue."
			end

			@status = :created
			self.class.queue_dir.join("10-created.d").join("#{job_id}.json").open('w') do |f|
				f.puts(JSON.dump(
					job: {
						uuid: job_id,
						token: Tint.token(job_id),
						ssh_private_key: site.ssh_private_key_path.read
					},
					site: site.to_h
				))
			end
		end

		def self.queue_dir
			return unless ENV["TRAVIS_WORKER_BASE_DIR"]
			PathHelpers.ensure(ENV["TRAVIS_WORKER_BASE_DIR"])
		end
	end
end
