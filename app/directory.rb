require_relative "resource"

module Tint
	class Directory < Resource
		def file(path)
			site.file(relative_path.join(path))
		end

		def files
			return @files if @files

			files = exist? ? children(false).map(&method(:file)) : []

			if relative_path.to_s != "."
				parent = Tint::File.new(site, relative_path.dirname, "..")
				files.unshift(parent)
			end

			@files = files.sort_by { |f| [f.directory? ? 0 : 1, f.name] }
		end
	end
end
