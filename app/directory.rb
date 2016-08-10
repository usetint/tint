require "pathname"

module Tint
	class Directory
		attr_reader :relative_path

		def initialize(site, relative_path)
			@site = site
			@relative_path = Pathname.new(relative_path).cleanpath
		end

		def user_id
			site.user_id
		end

		def route
			site.route("files/#{relative_path}")
		end

		def path
			@path ||= begin
				path = site.cache_path.join(relative_path).realdirpath

				unless path.to_s.start_with?(site.cache_path.to_s)
					raise "File is outside of project scope!"
				end

				path
			end
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

		def ==(other)
			other.path == path
		end

	protected

		attr_reader :site

	end
end
