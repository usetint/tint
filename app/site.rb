require "git"
require "tmpdir"

require_relative "file"
require_relative "directory"
require_relative "path_helpers"

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
			ensure_path(:cache_path)
		end

		def deploy_path
			ensure_path(:deploy_path)
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

		def clone(remote=@options[:remote])
			begin
				# First, do a shallow clone so that we are up and running
				Git.clone(remote, cache_path.basename, path: cache_path.dirname, depth: 1)

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
				git.fetch(remote, unshallow: true)
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

		def sync(remote=@options[:remote])
			if git? && cloned?
				git.fetch(remote)
				git.reset_hard("FETCH_HEAD")
			elsif !git?
				clone(remote)
			end
		end

		def commit_with(message, user=nil, depth=1, &block)
			raise "Push failed." if depth > 5

			Dir.mktmpdir("tint-push") do |dir|
				Git.clone(@options[:remote], "clone", path: dir, depth: 1)
				path = Pathname.new(dir).join("clone")
				git = Git.open(path.to_s)

				block.call(path)
				git.add(all: true)

				if maybe_commit(git, message, user)
					begin
						if ENV["SITE_PATH"]
							# If we push to a checked-out repository, we'll get nasty errors
							sync(path.to_s)
						else
							git.push
							sync
						end
					rescue Git::GitExecuteError
						commit_with(message, user, depth+1, &block)
					end
				end
			end
		end

	protected

		def maybe_commit(git, message, user)
			git.status.each do |f|
				if f.type
					if user && user[:email]
						git.commit("#{message} via tint", author: "#{user[:fn]} <#{user[:email]}>")
					else
						git.commit("#{message} via tint")
					end

					return true
				end
			end

			false
		end

		def ensure_path(key, env=key.to_s.upcase)
			PathHelpers.ensure(
				@options[key] || Pathname.new(ENV.fetch(env)).join(@options[:site_id].to_s)
			)
		end
	end
end
