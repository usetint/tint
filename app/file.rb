require "base64"
require "filemagic"
require "yaml"

require_relative "resource"
require_relative "directory"

module Tint
	class File < Resource
		def initialize(site, relative_path, name=nil)
			super(site, relative_path)
			@name = name
		end

		def text?
			mime.split("/").first == "text"
		end

		def image?
			mime.split("/").first == "image"
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

		def name
			@name ||= path.basename.to_s
		end

		def stream(force_binary=false)
			if !force_binary && text?
				path.each_line.with_index do |line, idx|
					yield line.chomp, idx
				end
			else
				f = path.open
				idx = 0
				until f.eof?
					yield f.read(4096), idx
					idx += 1
				end
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

		def stream_base64
			stream(true) do |chunk, _idx|
				yield Base64.encode64(chunk)
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
	end
end
