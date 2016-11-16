require "pathname"
require "securerandom"
require "slim"

require_relative "base"
require_relative "../input"
require_relative "../directory"
require_relative "../form_helpers"

module Tint
	module Controllers
		class File < Base
			def self.query(val)
				condition { request.query_string == val }
			end

			def self.if(block)
				condition(&block)
			end

			def slim(template, options={})
				return super(template, options) if template == :error

				if options[:layout].nil?
					super :"layouts/files", locals: { breadcrumbs: breadcrumbs } do
						super :"files/#{template}", options
					end
				else
					super :"files/#{template}", options
				end
			end

			error Tint::File::IncompatibleFrontmatter do
				render_error 500, env["sinatra.error"].message
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
						html = slim :source, locals: { path: resource.route }
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
						path: resource.route
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

					frontmatter = resource.frontmatter? && resource.frontmatter
					slim :binary, locals: {
						frontmatter: frontmatter,
						file: resource,
						input: Input::File.new(:file, "file", resource.relative_path, site)
					}
				end

				put "/?", params: :sha do
					depth = site.log.find_index { |commit| commit.sha == params[:sha] }
					return slim :error, locals: { message: "Cannot find that commit" } unless depth >= 0

					site.commit_with("Reverted to #{params[:sha][0..6]}", pundit_user, depth: depth + 1) do |dir|
						Git.open(dir).revert("#{params[:sha]}..HEAD", no_commit: true)
					end

					redirect to(site.route)
				end

				put "/*", params: :sha do
					depth = site.log.find_index { |commit| commit.sha == params[:sha] }
					return slim :error, locals: { message: "Cannot find that commit" } unless depth >= 0

					site.commit_with(
						"Reverted #{resource.relative_path} to #{params[:sha][0..6]}",
						pundit_user,
						depth: depth + 1
					) do |dir|
						Git.open(dir).checkout_file(params[:sha], resource.relative_path)
					end

					redirect to(resource.route)
				end

				put "/*", if: -> { params.has_key?("move") } do
					authorize resource, :update?

					if params["move"] == "0"
						moves.reject! { |file| file.relative_path == resource.relative_path }
					else
						moves << resource
					end

					redirect(back || to(resource.parent.route))
				end

				put "/*", params: :name do
					authorize resource, :update?

					new = resource.parent.resource(params[:name])
					if new.exist? && resource != new
						slim :error, locals: { message: "A file with that name already exists" }
					else
						if resource != new
							site.commit_with("Renamed #{resource.relative_path} to #{new.name}", pundit_user) do |dir|
								dir.join(resource.relative_path).rename(dir.join(new.relative_path))
							end
						end

						moves.reject! { |file| file.relative_path == resource.relative_path }

						redirect to(new.parent.route)
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

					if (params[:file].is_a?(Hash) && params[:file][:tempfile]) || params.has_key?("data")
						site.commit_with("Modified #{resource.relative_path}", pundit_user) do |dir|
							name = if params.has_key?("data")
								updated_data = FormHelpers.process(params[:data], dir)
								new_relative_path = resource.relative_path_with_frontmatter(updated_data)
								if new_relative_path != resource.relative_path
									dir.join(resource.relative_path).rename(dir.join(new_relative_path))
								end

								new_relative_path.basename.to_s
							else
								resource.name
							end

							if (params[:file].is_a?(Hash) && params[:file][:tempfile])
								FormHelpers.upload(dir.join(resource.parent.relative_path), params[:file], name)
							end
						end
					end

					redirect to(resource.parent.route)
				end

				put "/*" do
					authorize resource, :update?

					begin
						site.commit_with("Modified #{resource.relative_path}", pundit_user) do |dir|
							updated_data = FormHelpers.process(params[:data], dir)

							new_relative_path = resource.relative_path_with_frontmatter(updated_data)
							if new_relative_path != resource.relative_path
								dir.join(resource.relative_path).rename(dir.join(new_relative_path))
							end

							dir.join(new_relative_path).open("w") do |f|
								if updated_data
									if resource.yml?
										f.puts updated_data.to_yaml.sub(/\A---\r?\n?/, "")
									else
										f.puts updated_data.to_yaml
										f.puts "---"
									end

									if params.has_key?("content")
										f.puts(params[:content].encode(universal_newline: true))
									elsif !resource.yml?
										resource.stream_content(&f.method(:puts))
									end
								end
							end
						end

						redirect to(resource.parent.route)
					rescue FormHelpers::Invalid
						halt 500, $!.to_s
					end
				end

				["Makefile", ".tint.yml"].each do |template|
					post "/#{template}", params: :build_system do
						build_system = valid_build_system(params[:build_system])

						raise ArgumentError, "Must specify a valid build system" unless build_system

						site.commit_with("Created default #{build_system} #{template}", pundit_user) do |dir|
							FileUtils.cp(
								Pathname.new(__FILE__).join("../../../templates/#{build_system}/#{template}"),
								dir.join(template)
							)
						end

						redirect to(site.route)
					end
				end

				post "/?*", params: :file do
					authorize resource, :update?

					filename = resource.relative_path.join(params[:file][:filename])
					site.commit_with("Uploaded #{filename}", pundit_user) do |dir|
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

					site.commit_with("Removed #{resource.relative_path}", pundit_user) do |dir|
						dir.join(resource.relative_path).delete
					end

					redirect to(resource.parent.route)
				end
			end

		protected

			def valid_build_system(build_system)
				build_systems = [:jekyll]
				build_systems.find { |bs| bs.to_s == build_system.to_s }
			end

			def moves
				session["moves"] ||= {}
				session["moves"][site.route] ||= []
			end

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

			def breadcrumbs
				fragments = Array(params["splat"]).join("/").split("/")
				breadcrumbs = fragments.each_with_index.map { |_, i| site.resource(fragments[0..i].join("/")) }
				files = OpenStruct.new(fn: "files", route: site.route("files"))
				[site, files] + breadcrumbs
			end
		end
	end
end
