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
							begin
								site.git.lib.mv(file.relative_path.to_s, new.relative_path.to_s)
								commit(site.git, "Renamed #{file.relative_path} to #{new.name}")
							rescue Git::GitExecuteError
								# Not in git, so just rename
								file.rename(new.path)
							end
						end
					elsif params[:source]
						file.write params[:source].encode(universal_newline: true)

						add_and_commit(site, file, "Modified #{file.relative_path}")
					elsif params[:file]
						if params[:file].is_a?(Hash) && params[:file][:tempfile]
							file.parent.upload(params[:file], file.name)
							add_and_commit(site, file, "Modified #{file.relative_path}")
						end
					else
						updated_data = process_form_data(params[:data], site.git)

						Tempfile.open("tint-save") do |tmp|
							if updated_data
								if file.yml?
									tmp.puts updated_data.to_yaml.sub(/\A---\r?\n?/, "")
								else
									tmp.puts updated_data.to_yaml
									tmp.puts "---"
								end
							end

							if params.has_key?(:content)
								tmp.puts(params[:content].encode(universal_newline: true))
							elsif !file.yml?
								file.stream_content(&tmp.method(:puts))
							end

							tmp.flush
							# We have to use FileUtils#mv because
							# Pathname#rename does not work across filesystem boundaries
							FileUtils.mv(tmp.path, file.path.to_s, force: true)
						end

						add_and_commit(site, file, "Modified #{file.relative_path}")
					end

					redirect to(file.parent.route)
				end

				post "/?*" do
					directory = site.file(params["splat"].join("/")).to_directory
					authorize directory, :update?

					if params['file']
						file = directory.upload(params['file'])
						add_and_commit(site, file, "Uploaded #{file.relative_path}")
					elsif params['folder']
						folder = Tint::Directory.new(site, directory.relative_path.join(params["folder"]))
						return redirect to(folder.route)
					end

					redirect to(directory.route)
				end

				delete "/*" do
					file = site.file(params["splat"].join("/"))
					authorize file, :destroy?

					site.git.remove(file.path.to_s)
					commit(site.git, "Removed #{file.relative_path}")

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

			def process_form_data(data, git)
				case data
				when Array
					data.reject { |v| v.is_a?(String) && v.to_s == "" }.map { |v| process_form_data(v, git) }
				when Hash
					if data.keys.include?(:filename) && data.keys.include?(:tempfile)
						uploads = Tint::Directory.new(site, Pathname.new("uploads").join(Time.now.strftime("%Y")))
						uploads.mkpath
						file = uploads.upload(data.merge(filename: "#{SecureRandom.uuid}-#{data[:filename]}"))
						git.add(file.path.to_s)
						file.relative_path.to_s
					elsif data.keys.include?('___checkbox_unchecked')
						data.keys.include?('___checkbox_checked')
					elsif data.keys.include?("___datetime_date")
						datetime = "#{data["___datetime_date"]} #{data["___datetime_time"]}"
						Time.parse(datetime) if datetime.to_s != ""
					elsif data.keys.all? { |k| k =~ /\A\d+\Z/ }
						data.to_a.sort_by {|x| x.first.to_i }.map(&:last).map { |v| process_form_data(v, git) }
					else
						data.merge(data) do |k,v|
							v = Date.parse(v) if is_date?(k, v)
							process_form_data(v, git)
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

			def add_and_commit(site, file, message)
				site.git.add(file.path.to_s)
				site.git.status.each do |f|
					if f.path == file.relative_path.to_s && f.type
						commit(site.git, message)
					end
				end
			end

			def commit(git, message)
				if pundit_user && pundit_user[:email]
					git.commit("#{message} via tint", author: "#{pundit_user[:fn]} <#{pundit_user[:email]}>")
				else
					git.commit("#{message} via tint")
				end
			end
		end
	end
end
