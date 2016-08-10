require "pathname"

module Tint
	class Resource
		extend Forwardable

		attr_reader :relative_path

		def_delegators :site, :user_id

		def path
			@path ||= begin
				path = site.cache_path.join(relative_path).realdirpath

				unless path.to_s.start_with?(site.cache_path.to_s)
					raise "File is outside of project scope!"
				end

				path
			end
		end

		def ==(other)
			other.path == path
		end

	protected

		attr_reader :site
	end
end
