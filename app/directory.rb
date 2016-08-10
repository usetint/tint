require "pathname"

require_relative "resource"

module Tint
	class Directory < Resource
		def_delegators :site, :user_id

		def route
			site.route("files/#{relative_path}")
		end

		def file(path)
			site.file(relative_path.join(path))
		end

		def files
			return @files if @files

			files = path.exist? ? path.children(false).map(&method(:file)) : []

			if relative_path.to_s != "."
				parent = Tint::File.new(site, relative_path.dirname, "..")
				files.unshift(parent)
			end

			@files = files.sort_by { |f| [f.directory? ? 0 : 1, f.name] }
		end

		def upload(file, name=file[:filename])
			path.mkpath

			path.join(name).open("w") do |f|
				until file[:tempfile].eof?
					f.write file[:tempfile].read(4096)
				end
			end

			site.file(relative_path.join(file[:filename]))
		end
	end
end
