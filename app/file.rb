require "filemagic"
require "pathname"
require "yaml"

require_relative "directory"

module Tint
	class File
		attr_reader :relative_path

		def initialize(site, relative_path, name=nil)
			@site = site
			@relative_path = Pathname.new(relative_path).cleanpath

			@name = name
		end

		def user_id
			site.user_id
		end

		def exist?
			path.exist?
		end

		def directory?
			path.directory?
		end

		def parent
			@parent ||= Tint::Directory.new(site, relative_path.dirname)
		end

		def text?
			mime.split("/").first == "text"
		end

		def image?
			mime.split("/").first == "image"
		end

		def size
			path.size
		end

		def mime
			FileMagic.open(:mime) { |magic| magic.file(path.to_s) }
		end

		def markdown?
			[".md", ".markdown"].include? extension
		end

		def yml?
			[".yaml", ".yml"].include? extension
		end

		def route
			site.route("files/#{relative_path}")
		end

		def path
			unless @path
				@path = site.cache_path.join(relative_path).realdirpath

				unless @path.to_s.start_with?(site.cache_path.to_s)
					raise "File is outside of project scope!"
				end
			end

			@path
		end

		def name
			@name ||= path.basename.to_s
		end

		def stream
			path.each_line.with_index do |line, idx|
				yield line.chomp, idx
			end
		end

		def stream_content
			has_frontmatter = false
			doc_start = 0
			stream do |line, idx|
				if doc_start < 2
					has_frontmatter = true if line == '---' && idx == 0
					doc_start += 1 if line == '---'
					next if has_frontmatter
				end

				yield line
			end
		end

		def content?
			detect_content_or_frontmatter[0]
		end

		def frontmatter?
			detect_content_or_frontmatter[1]
		end

		def frontmatter
			YAML.safe_load(open(path), [Date, Time])
		end

		def to_directory
			Tint::Directory.new(site, relative_path)
		end

	protected

		def extension
			@extension ||= path.extname
		end

		def detect_content_or_frontmatter
			return @content_or_frontmatter if @content_or_frontmatter

			has_frontmatter = false
			path.each_line.with_index do |line, idx|
				line.chomp!
				if line == '---' && idx == 0
					has_frontmatter = true
					next
				end

				if has_frontmatter && line == '---'
					return [true, has_frontmatter]
				end
			end

			@content_or_frontmatter = [!has_frontmatter, has_frontmatter]
		end

		attr_reader :site

	end
end
