require "pathname"
require "securerandom"
require "slim"

require_relative "base"
require_relative "../input"
require_relative "../helpers"
require_relative "../directory"
require_relative "../form_helpers"

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
								FormHelpers.upload(dir.join(file.parent.relative_path), params[:file], file.name)
							end
						end
					else
						site.commit_with("Modified #{file.relative_path}") do |dir|
							updated_data = FormHelpers.process(params[:data], dir)
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

					if params[:file]
						site.commit_with("Uploaded #{directory.relative_path.join(params['file'][:filename])}") do |dir|
							FormHelpers.upload(dir.join(directory.relative_path), params[:file])
						end
					elsif params[:folder]
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
				html = slim :"layouts/files" do
					slim :"files/source", locals: { path: file.route }
				end

				stream_into_element("<textarea name=\"source\">", html, file)
			end

			def editor(file)
				frontmatter = file.frontmatter? && file.frontmatter
				html = slim :"layouts/files" do
					slim :"files/text", locals: {
						frontmatter: frontmatter,
						wysiwyg: file.markdown?,
						path: file.route
					}
				end

				stream_into_element("<textarea name=\"content\">", html, file)
			end

			def stream_into_element(el, html, file)
				stream do |out|
					top, bottom = html.split(el, 2)
					out.puts top
					out.puts el
					file.stream { |*args| out.puts args.first }
					out.puts bottom
				end
			end
		end
	end
end
