require "pathname"

module Tint
	class Directory
		def initialize(path)
			@path = Pathname.new(path)
		end

		def route
			"/files/#{relative_path}"
		end

		def relative_path
			path.relative_path_from(PROJECT_PATH)
		end

		def files
			return @files if @files

			files = Dir.glob("#{path}/*").map { |file| Tint::File.new(file) }

			if path.realpath != PROJECT_PATH
				parent = Tint::File.new(path.dirname, "..")
				files = files.unshift(parent)
			end

			@files = files.sort_by { |f| [f.directory? ? 0 : 1, f.name] }
		end

		def upload(file)
			file_path = path + file[:filename]

			::File.open(file_path, "w") do |f|
				until file[:tempfile].eof?
					f.write file[:tempfile].read(4096)
				end
			end

			Tint::File.new(file_path)
		end

		attr_reader :path
	end
end
