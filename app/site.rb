require "git"

module Tint
	class Site
		def initialize(options)
			@options = options
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

		def config
			@config ||= YAML.safe_load(open(cache_path.join(".tint.yml")), [Date, Time]) rescue {}
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

		def remote
			@options[:remote]
		end

		def clone
			begin
				# First, do a shallow clone so that we are up and running
				Git.clone(@options[:remote], cache_path.basename, path: cache_path.dirname, depth: 1)

				# Make sure the UI can tell we are ready to rock
				open(cache_path.join('.git').join('tint-cloned'), 'w').close
			rescue
				# Something went wrong.  Nuke the cache
				clear_cache!
				return
			end

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
