require "git"
require_relative "file"
require_relative "directory"

module Tint
	class Site
		def initialize(options)
			@options = options
		end

		def ==(other)
			other.is_a?(Tint::Site) && cache_path == other.cache_path
		end

		def to_h
			@options.dup
		end

		def route(sub='')
			"/#{@options[:site_id]}/#{sub}"
		end

		def fn
			@options[:fn]
		end

		def user_id
			@options[:user_id] && @options[:user_id].to_i
		end

		def cache_path
			@options[:cache_path] ||= Pathname.new(ENV.fetch("CACHE_PATH")).
			                          realpath.join(@options[:site_id].to_s)
			@options[:cache_path].mkpath
			@options[:cache_path]
		end

		def deploy_path
			@options[:deploy_path] ||= Pathname.new(ENV.fetch("PREFIX")).
			                           realpath.join(@options[:site_id].to_s)
			@options[:deploy_path].mkpath
			@options[:deploy_path]
		end

		def valid_config?
			begin
				unsafe_config
				true
			rescue
				false
			end
		end

		def unsafe_config
			config_file = cache_path.join(".tint.yml")
			config_file.exist? ? YAML.safe_load(config_file.open, [Date, Time]) : {}
		end

		def config
			@config ||= unsafe_config rescue {}
		end

		def file(path)
			Tint::File.new(self, path)
		end

		def git
			@git ||= Git.open(cache_path)
		end

		def git?
			cache_path.join('.git').directory?
		end

		def status
			status = @options[:status] || if defined?(DB)
				job = DB[:jobs].where(site_id: @options[:site_id]).order(:created_at).last
				job && "build_#{BuildJob.get(job[:job_id]).status}".to_sym
			end

			status && status.to_sym
		end

		def remote
			@options[:remote]
		end

		def build
			job = BuildJob.new(self)
			job.enqueue!

			DB[:jobs].insert(job_id: job.job_id, site_id: @options[:site_id], created_at: Time.now) if defined?(DB)

			job
		end

		def clone
			begin
				# First, do a shallow clone so that we are up and running
				Git.clone(@options[:remote], cache_path.basename, path: cache_path.dirname, depth: 1)

				# Make sure the UI can tell we are ready to rock
				open(cache_path.join('.git').join('tint-cloned'), 'w').close
			rescue
				DB[:sites].where(site_id: @options[:site_id]).update(status: "clone_failed")

				# Something went wrong.  Nuke the cache
				clear_cache!
				return
			end

			DB[:sites].where(site_id: @options[:site_id]).update(status: nil)

			begin
				# Now, fetch the history for future use
				git.fetch('origin', unshallow: true)
			rescue
				# Something went wrong, keep the shallow copy that at least works
			end
		end

		def clear_cache!
			cache_path.rmtree
		end

		def cloned?
			@options[:cloned] || cache_path.join('.git').join('tint-cloned').exist?
		end

		def sync
			if git? && cloned?
				git.fetch("origin")
				git.reset_hard("origin/master")
			elsif !git?
				clone
			end
		end
	end
end
