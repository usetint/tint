require "forwardable"
require "pathname"

module Tint
	class Resource
		extend Forwardable

		attr_reader :relative_path

		def_delegators :site, :users

		def initialize(site, relative_path, fn=nil)
			@site = site
			@relative_path = Pathname.new(relative_path).cleanpath
			unless @relative_path.relative?
				@relative_path = @relative_path.relative_path_from(Pathname.new("/"))
			end
			@fn = fn
		end

		def parent
			@parent ||= Tint::Directory.new(site, relative_path.dirname)
		end

		def route
			site.route(Pathname.new("files").join(relative_path).to_s)
		end

		def path
			@path ||= begin
				path = site.cache_path.join(relative_path)
				path = in_annex? ? final_target : path.realdirpath

				unless path.to_s.start_with?(site.cache_path.to_s)
					raise "File is outside of project scope!"
				end

				path
			end
		end

		def ==(other)
			other.is_a?(Resource) && other.path == path
		end

		def name
			relative_path.basename.to_s
		end

		def fn
			@fn ||= path == site.cache_path ? "files" : name
		end

		def in_annex?
			final_target.to_s.start_with?(
				site.cache_path.join(".git").join("annex").to_s
			)
		end

		def unlink
			# If we are a symlink, unlink ourselves, not the target
			site.cache_path.join(relative_path).unlink
		end

		def respond_to?(method)
			super || path.respond_to?(method)
		end

		def method_missing(method, *arguments, &block)
			path.public_send(method, *arguments, &block)
		end

		def to_h(_=nil)
			{
				fn: fn,
				route: route,
				path: relative_path.to_s,
				type: self.class.name.to_s.split("::").last.downcase
			}
		end

		def to_json(*args)
			to_h.to_json(*args)
		end

	protected

		attr_reader :site

		def final_target(pth=site.cache_path.join(relative_path))
			return pth unless pth.symlink?
			final_target(pth.dirname.join(pth.readlink))
		end
	end
end
