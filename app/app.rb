require "sinatra"
require "sinatra/json"
require "sinatra/reloader"
require "sinatra/streaming"

require "git"
require "pathname"
require "sass"
require "sprockets"

require_relative "file"
require_relative "directory"

module Tint
	PROJECT_PATH = Pathname.new(ENV["PROJECT_PATH"]).realpath

	class App < Sinatra::Base
		helpers Sinatra::Streaming

		configure :development do
			register Sinatra::Reloader
		end

		set :environment, Sprockets::Environment.new
		set :method_override, true

		environment.append_path "assets/stylesheets"
		environment.css_compressor = :scss

		get "/" do
			erb :index
		end

		get "/assets/*" do
			env["PATH_INFO"].sub!("/assets", "")
			settings.environment.call(env)
		end

		get "/files/?*" do
			file = Tint::File.get(params)

			if file.directory?
				render_directory file.to_directory
			elsif file.text?
				if params.has_key?('source')
					stream do |out|
						html = erb :"layouts/files" do
							erb :"files/source", locals: { path: file.route }
						end
						top, bottom = html.split('<textarea name="source">', 2)
						out.puts top
						out.puts '<textarea name="source">'
						file.stream { |line, _| out.puts line }
						out.puts bottom
					end
				elsif file.yml? || !file.content?
					erb :"layouts/files" do
						erb :"files/yml", locals: {
							data: file.frontmatter,
							path: file.route
						}
					end
				else
					frontmatter = file.frontmatter? && file.frontmatter
					stream do |out|
						html = erb :"layouts/files" do
							erb :"files/text", locals: {
								frontmatter: frontmatter,
								wysiwyg: file.markdown?,
								path: file.route
							}
						end
						top, bottom = html.split('<textarea name="content">', 2)
						out.puts top
						out.puts '<textarea name="content">'
						file.stream_content(&out.method(:puts))
						out.puts bottom
					end
				end
			else
				'Editing binary files is not supported'
			end
		end

		put "/files/*" do
			file = Tint::File.get(params)
			g = Git.open(PROJECT_PATH)

			if params['name']
				new = file.relative_path.dirname.join(params['name'])
				if PROJECT_PATH.join(new).exist?
					return 'A file with that name already exists'
				else
					begin
						g.lib.mv(file.relative_path.to_s, new.to_s)
						g.commit("Renamed #{file.relative_path} to #{params['name']} via tint")
					rescue Git::GitExecuteError
						# Not in git, so just rename
						file.path.rename(PROJECT_PATH.join(new))
					end
				end
			elsif params['source']
				file.path.write params['source']

				g.add(file.path.to_s)

				g.status.each do |f|
					if f.path == file.relative_path.to_s && f.type
						g.commit("Modified #{file.relative_path} via tint")
					end
				end
			else
				updated_data = normalize(params['data'])

				Tempfile.open('tint-save') do |tmp|
					if updated_data
						if file.content?
							tmp.puts updated_data.to_yaml
							tmp.puts '---'
						else
							tmp.puts updated_data.to_yaml.sub(/\A---\r?\n?/, '')
						end
					end
					if params.has_key?('content')
						tmp.puts(params['content'].gsub(/\r\n?/, "\n"))
					else
						file.stream_content(&tmp.method(:puts))
					end
					tmp.flush
					FileUtils.mv(tmp.path, file.path, force: true)
				end

				g.add(file.path.to_s)

				g.status.each do |f|
					if f.path == file.relative_path.to_s && f.type
						g.commit("Modified #{file.relative_path} via tint")
					end
				end
			end

			redirect to(file.parent.route)
		end

		post "/files/?*" do
			directory = Tint::File.get(params).to_directory
			if params['file']
				file = directory.upload(params['file'])

				g = Git.open(PROJECT_PATH)
				g.add(file.path.to_s)
				g.status.each do |f|
					if f.path == file.relative_path.to_s && f.type
						g.commit("Uploaded #{file.relative_path} via tint")
					end
				end
			elsif params['folder']
				folder = directory.path.join(params['folder'])
				folder.mkdir
				return redirect to(Tint::Directory.new(folder).route)
			end

			redirect to(directory.route)
		end

		delete "/files/*" do
			file = Tint::File.get(params)

			g = Git.open(PROJECT_PATH)
			g.remove(file.path.to_s)
			g.commit("Removed #{file.relative_path} via tint")

			redirect to(file.parent.route)
		end

	protected

		def render_directory(directory)
			erb :"layouts/files", locals: { directory: directory } do
				erb :"files/index", locals: { directory: directory }
			end
		end

		def normalize(data)
			case data
			when Array
				data.map &method(:normalize)
			when Hash
				if data.keys.include?('___checkbox_unchecked')
					data.keys.include?('___checkbox_checked')
				elsif data.keys.all? { |k| k =~ /\A\d+\Z/ }
					data.to_a.sort_by {|x| x.first.to_i }.map(&:last).map &method(:normalize)
				else
					data.merge(data) { |k,v| normalize(v) }
				end
			else
				data
			end
		end

		helpers do
			def render_yml(value)
				"#{
				case value
				when Hash
					value.map { |k, v| render_value(k, v, "data[#{k}]") }.join
				when Array
					"<ol data-key='data'>#{value.each_with_index.map { |v, i| "<li>#{render_value(nil, v, "data[#{i}]")}" }.join}</ol>"
				else
					raise TypeError, 'YAML root must be a Hash or Array'
				end
				}<script type='text/javascript' src='/yaml.js'></script>"
			end

			def render_value(key, value, name)
				case value
				when Hash
					"<fieldset#{" class='hidden'" if key.to_s.start_with?("_")}>#{"<legend>#{key}</legend>" if key}#{
					value.map do |key, value|
						"#{render_value(key, value, "#{name}[#{key}]")}"
					end.join
					}</fieldset>"
				when Array
					"<fieldset#{" class='hidden'" if key.to_s.start_with?("_")}><legend>#{key}</legend><ol data-key='#{name}'>#{
						value.each_with_index.map { |v, i| "<li>#{render_value(nil, v, "#{name}[#{i}]")}</li>" }.join
					}</ol></fieldset>"
				else
					render_input(key, value, name)
				end
			end

			def render_input(key, value, name)
				input = if [true, false].include? value
					"
						<input type='hidden' name='#{name}[___checkbox_unchecked]' value='' />
						<input type='checkbox' name='#{name}[___checkbox_checked]' #{' checked="checked"' if value} />
					"
				elsif value.is_a?(String) && value.length > 50
					"<textarea name='#{name}'>#{value}</textarea>"
				else
					"<input type='text' name='#{name}' value='#{value}' />"
				end

				if key
					"<label#{" class='hidden'" if key.to_s.start_with?("_")}>#{key} #{input}</label>"
				else
					input
				end
			end
		end
	end
end
