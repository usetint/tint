require "pathname"
require "securerandom"
require "slim"

require_relative "base"
require_relative "../input"
require_relative "../helpers"
require_relative "../directory"

module Tint
	module Controllers
		class File < Base
			helpers Tint::Helpers::Rendering

			namespace "/:site/files" do
				get "/?*" do
					file = site.file(params['splat'].join('/'))

					if params[:download] && file.exist? && !file.directory?
						authorize file, :show?
						return send_file file.path, filename: file.name, type: file.mime, disposition: :attachment
					end

					if file.directory? || !file.exist?
						authorize file.to_directory, :index?
						render_directory file.to_directory
					elsif file.text?
						authorize file, :edit?

						if params.has_key?('source')
							source(file)
						elsif file.yml? || !file.content?
							slim :"layouts/files" do
								slim :"files/yml", locals: {
									data: file.frontmatter,
									path: file.route
								}
							end
						else
							editor(file)
						end
					else
						authorize file, :edit?

						slim :"layouts/files" do
							slim :"files/binary", locals: { file: file, input: Input::File.new(:file, "file", file.relative_path, site) }
						end
					end
				end

				put "/*" do
					file = site.file(params["splat"].join("/"))
					authorize file, :update?

					if params[:name]
						new = file.parent.file(params[:name])
						if new.exist?
							return slim :error, locals: { message: "A file with that name already exists" }
						else
							site.commit_with("Renamed #{file.relative_path} to #{new.name}", pundit_user) do |dir|
								dir.join(file.relative_path).rename(dir.join(new.relative_path))
							end
						end
					elsif params[:source]
						site.commit_with("Modified #{file.relative_path}", pundit_user) do |dir|
							dir.join(file.relative_path).write params[:source].encode(universal_newline: true)
						end
					elsif params[:file]
						if params[:file].is_a?(Hash) && params[:file][:tempfile]
							site.commit_with("Modified #{file.relative_path}") do |dir|
								upload(dir.join(file.parent.relative_path), params[:file], file.name)
							end
						end
					else
						site.commit_with("Modified #{file.relative_path}") do |dir|
							updated_data = process_form_data(params[:data], dir)
							dir.join(file.relative_path).open("w") do |f|
								if updated_data
									if file.yml?
										f.puts updated_data.to_yaml.sub(/\A---\r?\n?/, "")
									else
										f.puts updated_data.to_yaml
										f.puts "---"
									end
								end

								if params.has_key?(:content)
									f.puts(params[:content].encode(universal_newline: true))
								elsif !file.yml?
									file.stream_content(&f.method(:puts))
								end
							end
						end
					end

					redirect to(file.parent.route)
				end

				post "/?*" do
					directory = site.file(params["splat"].join("/")).to_directory
					authorize directory, :update?

					if params['file']
						site.commit_with("Uploaded #{directory.relative_path.join(params['file'][:filename])}") do |dir|
							upload(dir.join(directory.relative_path), params[:file])
						end
					elsif params['folder']
						folder = Tint::Directory.new(site, directory.relative_path.join(params["folder"]))
						return redirect to(folder.route)
					end

					redirect to(directory.route)
				end

				delete "/*" do
					file = site.file(params["splat"].join("/"))
					authorize file, :destroy?

					site.commit_with("Removed #{file.relative_path}") do |dir|
						dir.join(file.relative_path).delete
					end

					redirect to(file.parent.route)
				end
			end

		protected

			def render_directory(directory)
				slim :"layouts/files", locals: { directory: directory } do
					slim :"files/index", locals: { directory: directory }
				end
			end

			def source(file)
				stream do |out|
					html = slim :"layouts/files" do
						slim :"files/source", locals: { path: file.route }
					end
					top, bottom = html.split('<textarea name="source">', 2)
					out.puts top
					out.puts '<textarea name="source">'
					file.stream { |line, _| out.puts line }
					out.puts bottom
				end
			end

			def editor(file)
				frontmatter = file.frontmatter? && file.frontmatter
				stream do |out|
					html = slim :"layouts/files" do
						slim :"files/text", locals: {
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

			def process_form_data(data, dir)
				case data
				when Array
					data.reject { |v| v.is_a?(String) && v.to_s == "" }.map { |v| process_form_data(v, dir) }
				when Hash
					if data.keys.include?(:filename) && data.keys.include?(:tempfile)
						uploads = dir.join("uploads").join(Time.now.strftime("%Y"))
						filename = "#{SecureRandom.uuid}-#{data[:filename]}"
						upload(uploads, data, filename)
						uploads.join(filename).to_s
					elsif data.keys.include?('___checkbox_unchecked')
						data.keys.include?('___checkbox_checked')
					elsif data.keys.include?("___datetime_date")
						datetime = "#{data["___datetime_date"]} #{data["___datetime_time"]}"
						Time.parse(datetime) if datetime.to_s != ""
					elsif data.keys.all? { |k| k =~ /\A\d+\Z/ }
						data.to_a.sort_by {|x| x.first.to_i }.map(&:last).map { |v| process_form_data(v, dir) }
					else
						data.merge(data) do |k,v|
							v = Date.parse(v) if is_date?(k, v)
							process_form_data(v, dir)
						end
					end
				else
					data
				end
			end

			def is_date?(field_name, value)
				(field_name.end_with?("_date") || field_name == "date") &&
					value.is_a?(String) &&
					value.to_s != ""
			end

			def upload(dir, file, name=file[:filename])
				dir.mkpath

				dir.join(name).open("w") do |f|
					file[:tempfile].rewind # In case of retry, rewind
					until file[:tempfile].eof?
						f.write file[:tempfile].read(4096)
					end
				end
			end
		end
	end
end
