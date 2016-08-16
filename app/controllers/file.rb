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

			def self.query(val)
				condition { request.query_string == val }
			end

			def self.directory(_)
				condition { resource.directory? || !resource.exist? }
			end

			def self.text(_)
				condition { resource.text? }
			end

			def self.yml(_)
				condition { resource.yml? || !resource.content? }
			end

			def self.rename(_)
				condition { !!params[:name] }
			end

			def self.source(_)
				condition { !!params[:source] }
			end

			def self.upload(_)
				condition { !!params[:file] }
			end

			def self.new_folder(_)
				condition { !!params[:folder] }
			end

			namespace "/:site/files" do
				get "/?*", query: "download" do
					if resource.exist? && resource.file?
						authorize resource, :show?
						send_file resource.path, filename: resource.name, type: resource.mime, disposition: :attachment
					else
						slim :error, locals: { message: "Only files may be downloaded." }
					end
				end

				get "/?*", query: "source" do
					authorize resource, :edit?

					if resource.text?
						html = slim :"layouts/files" do
							slim :"files/source", locals: { path: resource.route }
						end

						stream_into_element("<textarea name=\"source\">", html, resource)
					else
						slim :error, locals: { message: "Only text files may be edited by source" }
					end
				end

				get "/?*", directory: true do
					authorize resource, :index?

					slim :"layouts/files", locals: { directory: resource } do
						slim :"files/index", locals: { directory: resource }
					end
				end

				get "/?*", yml: true do
					authorize resource, :edit?

					slim :"layouts/files" do
						slim :"files/yml", locals: {
							data: resource.frontmatter,
							path: resource.route
						}
					end
				end

				get "/?*", text: true do
					authorize resource, :edit?

					frontmatter = resource.frontmatter? && resource.frontmatter
					html = slim :"layouts/files" do
						slim :"files/text", locals: {
							frontmatter: frontmatter,
							wysiwyg: resource.markdown?,
							path: resource.route
						}
					end

					stream_into_element("<textarea name=\"content\">", html, resource)
				end

				get "/?*" do
					authorize resource, :edit?
					slim :"layouts/files" do
						slim :"files/binary", locals: {
							file: resource,
							input: Input::File.new(:file, "file", resource.relative_path, site)
						}
					end
				end

				put "/*", rename: true do
					authorize resource, :update?

					new = resource.parent.resource(params[:name])
					if new.exist?
						slim :error, locals: { message: "A file with that name already exists" }
					else
						site.commit_with("Renamed #{resource.relative_path} to #{new.name}", pundit_user) do |dir|
							dir.join(resource.relative_path).rename(dir.join(new.relative_path))
						end

						redirect to(resource.parent.route)
					end
				end

				put "/*", source: true do
					authorize resource, :update?

					site.commit_with("Modified #{resource.relative_path}", pundit_user) do |dir|
						dir.join(resource.relative_path).write params[:source].encode(universal_newline: true)
					end

					redirect to(resource.parent.route)
				end

				put "/*", upload: true do
					authorize resource, :update?

					if params[:file].is_a?(Hash) && params[:file][:tempfile]
						site.commit_with("Modified #{resource.relative_path}") do |dir|
							FormHelpers.upload(dir.join(resource.parent.relative_path), params[:file], resource.name)
						end
					end

					redirect to(resource.parent.route)
				end

				put "/*" do
					authorize resource, :update?

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

					redirect to(resource.parent.route)
				end

				post "/?*", upload: true do
					authorize resource, :update?

					site.commit_with("Uploaded #{resource.relative_path.join(params[:file][:filename])}") do |dir|
						FormHelpers.upload(dir.join(resource.relative_path), params[:file])
					end

					redirect to(resource.route)
				end

				post "/?*", new_folder: true do
					authorize resource, :update?

					new_folder = Tint::Directory.new(site, resource.relative_path.join(params[:folder]))
					redirect to(new_folder.route)
				end

				delete "/*" do
					authorize resource, :destroy?

					site.commit_with("Removed #{resource.relative_path}") do |dir|
						dir.join(resource.relative_path).delete
					end

					redirect to(resource.parent.route)
				end
			end

		protected

			def resource
				site.resource(params[:splat].join("/"))
			end

			def stream_into_element(el, html, resource)
				stream do |out|
					top, bottom = html.split(el, 2)
					out.puts top
					out.puts el
					resource.stream { |*args| out.puts args.first }
					out.puts bottom
				end
			end
		end
	end
end
