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

		def clone
			Git.clone(@options[:remote], cache_path.basename, path: cache_path.dirname, depth: 1)
			open(cache_path.join('.git').join('tint-cloned'), 'w').close
		end

		def cloned?
			cache_path.join('.git').join('tint-cloned').exist?
		end
	end
end
