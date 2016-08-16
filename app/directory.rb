require_relative "resource"

module Tint
	class Directory < Resource
		def resource(path)
			site.resource(relative_path.join(path))
		end

		def files
			return @files if @files

			files = exist? ? children(false).map(&method(:resource)) : []

			if relative_path.to_s != "."
				parent = self.class.new(site, relative_path.dirname, "..")
				files.unshift(parent)
			end

			@files = files.sort_by { |f| [f.directory? ? 0 : 1, f.name] }
		end
	end
end
