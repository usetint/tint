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

			set(:query) { |val| condition { request.query_string == val } }

			namespace "/:site/files" do
				get "/?*", query: "download" do
					if resource.exist? && resource.file?
						authorize resource, :show?
						send_file resource.path, filename: resource.name, type: resource.mime, disposition: :attachment
					end
				end

				get "/?*" do
					if resource.directory? || !resource.exist?
						authorize resource, :index?
						render_directory resource
					elsif resource.text?
						authorize resource, :edit?

						if params.has_key?('source')
							source(resource)
						elsif resource.yml? || !resource.content?
							slim :"layouts/files" do
								slim :"files/yml", locals: {
									data: resource.frontmatter,
									path: resource.route
								}
							end
						else
							editor(resource)
						end
					else
						authorize file, :edit?

						slim :"layouts/files" do
							slim :"files/binary", locals: { file: resource, input: Input::File.new(:file, "file", resource.relative_path, site) }
						end
					end
				end

				put "/*" do
					authorize resource, :update?

					if params[:name]
						new = resource.parent.resource(params[:name])
						if new.exist?
							return slim :error, locals: { message: "A file with that name already exists" }
						else
							site.commit_with("Renamed #{resource.relative_path} to #{new.name}", pundit_user) do |dir|
								dir.join(resource.relative_path).rename(dir.join(new.relative_path))
							end
						end
					elsif params[:source]
						site.commit_with("Modified #{resource.relative_path}", pundit_user) do |dir|
							dir.join(resource.relative_path).write params[:source].encode(universal_newline: true)
						end
					elsif params[:file]
						if params[:file].is_a?(Hash) && params[:file][:tempfile]
							site.commit_with("Modified #{resource.relative_path}") do |dir|
								FormHelpers.upload(dir.join(resource.parent.relative_path), params[:file], resource.name)
							end
						end
					else
						site.commit_with("Modified #{resource.relative_path}") do |dir|
							updated_data = FormHelpers.process(params[:data], dir)
							dir.join(resource.relative_path).open("w") do |f|
								if updated_data
									if resource.yml?
										f.puts updated_data.to_yaml.sub(/\A---\r?\n?/, "")
									else
										f.puts updated_data.to_yaml
										f.puts "---"
									end
								end

								if params.has_key?(:content)
									f.puts(params[:content].encode(universal_newline: true))
								elsif !resource.yml?
									resource.stream_content(&f.method(:puts))
								end
							end
						end
					end

					redirect to(resource.parent.route)
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

			def resource
				site.resource(params[:splat].join("/"))
			end

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
