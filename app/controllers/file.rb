require "pathname"
require "securerandom"
require "slim"
require "slim/mustache"

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

			def self.params(key)
				condition { !!params[key] }
			end

			def self.if(block)
				condition(&block)
			end

			def slim(template, options)
				return super(template, options) if template == :error

				super :"layouts/files" do
					super :"files/#{template}", options
				end
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
						slim :source, locals: { path: resource.route }
						stream_into_element("<textarea name=\"source\">", html, resource)
					else
						slim :error, locals: { message: "Only text files may be edited by source" }
					end
				end

				get "/?*", if: -> { resource.directory? || !resource.exist? } do
					authorize resource, :index?
					respond_with :index, resource
				end

				get "/?*", if: -> { resource.yml? || !resource.content? } do
					authorize resource, :edit?

					slim :yml, locals: {
						data: resource.frontmatter,
						path: resource.route,
						root:	site.route("files")
					}
				end

				get "/?*", if: -> { resource.text? } do
					authorize resource, :edit?

					frontmatter = resource.frontmatter? && resource.frontmatter
					html = slim :text, locals: {
						frontmatter: frontmatter,
						wysiwyg: resource.markdown?,
						path: resource.route
					}

					stream_into_element("<textarea name=\"content\">", html, resource, :stream_content)
				end

				get "/?*" do
					authorize resource, :edit?
					slim :binary, locals: {
						file: resource,
						input: Input::File.new(:file, "file", resource.relative_path, site)
					}
				end

				put "/*", params: :name do
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

				put "/*", params: :source do
					authorize resource, :update?

					site.commit_with("Modified #{resource.relative_path}", pundit_user) do |dir|
						dir.join(resource.relative_path).write params[:source].encode(universal_newline: true)
					end

					redirect to(resource.parent.route)
				end

				put "/*", params: :file do
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

				post "/?*", params: :file do
					authorize resource, :update?

					site.commit_with("Uploaded #{resource.relative_path.join(params[:file][:filename])}") do |dir|
						FormHelpers.upload(dir.join(resource.relative_path), params[:file])
					end

					redirect to(resource.route)
				end

				post "/?*", params: :folder do
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

			def stream_into_element(el, html, resource, stream_method=:stream)
				stream do |out|
					top, bottom = html.split(el, 2)
					out.puts top
					out.puts el
					resource.public_send(stream_method) { |*args| out.puts args.first }
					out.puts bottom
				end
			end
		end
	end
end
