require "filemagic"
require "slugify"
require "yaml"

require_relative "directory"
require_relative "input"
require_relative "resource"

module Tint
	class File < Resource
		def text?
			mime.split("/").first == "text"
		end

		def image?
			mime.split("/").first == "image"
		end

		def mime
			if exist?
				FileMagic.open(:mime) { |magic| magic.file(path.to_s) }
			elsif symlink?
				"inode/symlink"
			else
				"inode/x-empty"
			end
		end

		def markdown?
			[".md", ".markdown"].include? extension
		end

		def yml?
			[".yaml", ".yml"].include? extension
		end

		def template?
			name.start_with?(".template")
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

		def content?
			return false if image?
			detect_content_or_frontmatter[0]
		end

		def frontmatter?
			return false if image?
			detect_content_or_frontmatter[1] || filename_frontmatter_candidates.length > 0
		end

		def frontmatter
			return if image?

			from_filename = filename_frontmatter_candidates.reduce({}) do |data, pieces|
				data.merge(try_filename_frontmatter_candidate(pieces))
			end

			# From frontmatter takes precedence
			from_front = YAML.safe_load(open(path), [Date, Time, Now]) || {} rescue {}
			if from_filename.empty?
				from_front
			elsif from_filename.class != from_front.class
				raise IncompatibleFrontmatter,
					"Files with frontmatter in their filename cannot have a #{from_front.class.name} as their root element."
			else
				from_filename.merge(from_front)
			end
		end

		def relative_path_with_frontmatter(front=frontmatter, ext=extension)
			return relative_path unless filename_frontmatter_candidates.first
			parent.relative_path.join(filename_frontmatter_candidates.first.map { |piece|
				format_piece(piece, front[piece["key"]]).to_s
			}.join + ext.to_s)
		end

		def to_h(_=nil)
			super.merge(mime: mime)
		end

		def log
			site.log.path(relative_path)
		end

	protected

		def extension
			@extension ||= path.extname
		end

		def detect_content_or_frontmatter
			return [false, false] unless exist?

			@content_or_frontmatter ||= begin
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

				[!has_frontmatter, has_frontmatter]
			end
		end

		def filename_frontmatter_candidates
			@filename_frontmatter_candidates ||=
				(site.config["filename_frontmatter"] || {}).map do |(glob, pieces)|
					relative_path.fnmatch?(glob) || basename.fnmatch?(glob) ? pieces : nil
				end.compact
		end

		def try_filename_frontmatter_candidate(pieces)
			data, final_path = pieces.reduce([{}, path.basename.to_s]) do |(acc, path), piece|
				if (result = piece_match(piece, path))
					[piece["key"] ? acc.merge(piece["key"] => result[:data]) : acc, result[:path]]
				else
					return {} # Did not match
				end
			end

			return {} unless final_path == "" || final_path[0] == "." # Must consume whole filename

			data
		end

		def piece_default(piece)
			piece["default"] || case piece["format"]
				when "slugify"
					"slug"
				else
					piece["match"]
			end
		end

		def format_piece(piece, value)
			if piece.has_key?("strptime")
				value = (value || Time.now).strftime(piece["strptime"])
			else
				value ||= piece_default(piece)
			end

			case piece["format"]
				when "slugify"
					value.slugify
				else
					value.to_s
			end
		end

		def piece_match(piece, path)
			if piece.has_key?("match") && (match = /^#{piece["match"]}/.match(path))
				{ data: match.to_s, path: match.post_match }
			elsif piece.has_key?("strptime")
				begin
					time = if Input.type(piece["key"], nil, site) == Input::Date
						Date.strptime(path, piece["strptime"])
					else
						Time.strptime(path, piece["strptime"])
					end
					{ data: time, path: path.sub(time.strftime(piece["strptime"]), "") }
				rescue ArgumentError
					# Parse failed, so return nil
				end
			end
		end

		class IncompatibleFrontmatter < TypeError
		end

		class Now < String
			yaml_tag "!now"
			def init_with(_coder)
				self << Time.now.iso8601
			end
		end
	end
end
