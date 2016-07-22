require "filemagic"
require "pathname"
require "yaml"

require_relative "directory"

module Tint
	class File
		attr_reader :path

		def initialize(path, name=nil)
			@path = Pathname.new(path).realpath.cleanpath
			unless @path.to_s.start_with?(PROJECT_PATH.to_s)
				raise "File is outside of project scope!"
			end

			@name = name
		end

		def self.get(params)
			Tint::File.new(PROJECT_PATH.join(params['splat'].join('/')))
		end

		def directory?
			::File.directory?(path)
		end

		def parent
			@parent ||= Tint::Directory.new(path.dirname)
		end

		def text?
			FileMagic.open(:mime) do |magic|
				magic.file(path.to_s).split('/').first == 'text'
			end
		end

		def markdown?
			[".md", ".markdown"].include? extension
		end

		def yml?
			[".yaml", ".yml"].include? extension
		end

		def root?
			path == PROJECT_PATH
		end

		def route
			"/files/#{relative_path}"
		end

		def relative_path
			path.relative_path_from(PROJECT_PATH)
		end

		def name
			@name ||= path.basename.to_s
		end

		def stream
			::File.foreach(path).with_index do |line, idx|
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
			YAML.safe_load(open(path), [Time])
		end

		def to_directory
			Tint::Directory.new(path)
		end

	protected

		def extension
			@extension ||= path.extname
		end

		def detect_content_or_frontmatter
			return @content_or_frontmatter if @content_or_frontmatter

			has_frontmatter = false
			::File.foreach(path).with_index do |line, idx|
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
