require "sinatra"
require "sinatra/json"
require "sinatra/reloader"
require "sinatra/streaming"
require 'sinatra/pundit'

require "git"
require "json"
require "omniauth"
require "omniauth-github"
require "omniauth-indieauth"
require "pathname"
require "sass"
require "securerandom"
require "sequel"
require "shellwords"
require "sprockets"

require_relative "directory"
require_relative "file"
require_relative "helpers"
require_relative "site"
require_relative "tint_omniauth" # Monkeypatch

ENV["GIT_COMMITTER_NAME"] = "Tint"
ENV["GIT_COMMITTER_EMAIL"] = "commit@usetint.com"

module Tint
	DB = Sequel.connect(ENV.fetch("DATABASE_URL")) unless ENV['SITE_PATH']

	class App < Sinatra::Base
		use OmniAuth::Builder do
			if ENV['GITHUB_KEY']
				provider :github, ENV['GITHUB_KEY'], ENV['GITHUB_SECRET'], scope: "user,repo"
			end

			if ENV['APP_URL']
				provider :indieauth, client_id: ENV['APP_URL']
			end
		end
		register Sinatra::Pundit
		helpers Sinatra::Streaming, Tint::Helpers::Rendering

		configure :development do
			set :show_exceptions, :after_handler
			register Sinatra::Reloader
		end

		configure do
			error Pundit::NotAuthorizedError do
				redirect to("/auth/login")
			end
		end

		enable :sessions
		set :session_secret, ENV["SESSION_SECRET"]
		set :sprockets, Sprockets::Environment.new
		set :method_override, true

		sprockets.append_path "assets/stylesheets"
		sprockets.css_compressor = :scss

		current_user do
			if ENV['SITE_PATH']
				{ user_id: 1 }
			else
				DB[:users][user_id: session['user'].to_i] if session['user']
			end
		end

		after do
			verify_authorized
		end

		get "/auth/login" do
			skip_authorization
			erb :login
		end

		delete "/auth/login" do
			skip_authorization
			session['user'] = nil
			redirect to("/")
		end

		get "/auth/:provider/callback" do
			skip_authorization

			identity = DB[:identities][provider: params["provider"], uid: request.env["omniauth.auth"].uid]

			if identity
				session["user"] = identity[:user_id]
			else
				session['user'] = DB[:users].insert(
					fn: request.env["omniauth.auth"].info.name,
					email: request.env["omniauth.auth"].info.email
				)

				DB[:identities].insert(
					provider: params["provider"],
					uid: request.env["omniauth.auth"].uid,
					omniauth: request.env["omniauth.auth"].to_json,
					user_id: session["user"]
				)
			end

			redirect to("/")
		end

		get "/assets/*" do
			skip_authorization
			env["PATH_INFO"].sub!("/assets", "")
			settings.sprockets.call(env)
		end

		get "/" do
			if ENV['SITE_PATH']
				authorize site, :index?
				erb :"site/index", locals: { site: site }
			else
				authorize Tint::Site, :index?
				erb :index, locals: { sites: policy_scope(Tint::Site) }
			end
		end

		post "/" do
			authorize Tint::Site, :create?

			site_id = DB[:sites].insert(
				user_id: pundit_user[:user_id],
				fn: params["fn"],
				remote: params["remote"]
			)

			redirect to("/#{site_id}/")
		end

		get "/:site/" do
			authorize site, :index?

			unless site.git?
				Thread.new { site.clone }
			end

			erb :"site/index", locals: { site: site }
		end

		post "/:site/build" do
			# No harm in letting anyone rebuild
			# This is also a webhook
			skip_authorization

			prefix = Pathname.new(ENV["PREFIX"])
			prefix.mkpath
			prefix = Shellwords.escape(prefix.realpath.to_s)
			project = Shellwords.escape(site.cache_path.to_s)
			success = system("env -i - PATH=\"#{ENV['PATH']}\" GEM_PATH=\"#{ENV['GEM_PATH']}\" /bin/sh -c 'cd #{project} && make PREFIX=#{prefix} && make install PREFIX=#{prefix}'")
			if success
				redirect to("/")
			else
				erb :error, locals: { message:  "Something went wrong with the build" }
			end
		end

		get "/:site/files/?*" do
			file = site.file(params['splat'].join('/'))

			if file.directory? || !file.exist?
				authorize file.to_directory, :index?
				render_directory file.to_directory
			elsif file.text?
				authorize file, :edit?

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
				erb :error, locals: { message: "Editing binary files is not supported" }
			end
		end

		put "/:site/files/*" do
			file = site.file(params["splat"].join("/"))
			authorize file, :update?

			if params["name"]
				new = file.parent.file(params["name"])
				if new.path.exist?
					return erb :error, locals: { message: "A file with that name already exists" }
				else
					begin
						site.git.lib.mv(file.relative_path.to_s, new.relative_path.to_s)
						commit(site.git, "Renamed #{file.relative_path} to #{new.name}")
					rescue Git::GitExecuteError
						# Not in git, so just rename
						file.path.rename(new.path)
					end
				end
			elsif params["source"]
				file.path.write params["source"].encode(universal_newline: true)

				site.git.add(file.path.to_s)

				site.git.status.each do |f|
					if f.path == file.relative_path.to_s && f.type
						commit(site.git, "Modified #{file.relative_path}")
					end
				end
			else
				updated_data = process_form_data(params["data"], site.git)

				Tempfile.open("tint-save") do |tmp|
					if updated_data
						if file.yml?
							tmp.puts updated_data.to_yaml.sub(/\A---\r?\n?/, "")
						else
							tmp.puts updated_data.to_yaml
							tmp.puts "---"
						end
					end

					if params.has_key?("content")
						tmp.puts(params["content"].encode(universal_newline: true))
					elsif !file.yml?
						file.stream_content(&tmp.method(:puts))
					end

					tmp.flush
					# We have to use FileUtils#mv because
					# Pathname#rename does not work across filesystem boundaries
					FileUtils.mv(tmp.path, file.path.to_s, force: true)
				end

				site.git.add(file.path.to_s)

				site.git.status.each do |f|
					if f.path == file.relative_path.to_s && f.type
						commit(site.git, "Modified #{file.relative_path}")
					end
				end
			end

			redirect to(file.parent.route)
		end

		post "/:site/files/?*" do
			directory = site.file(params["splat"].join("/")).to_directory
			authorize directory, :update?

			if params['file']
				file = directory.upload(params['file'])

				site.git.add(file.path.to_s)
				site.git.status.each do |f|
					if f.path == file.relative_path.to_s && f.type
						commit(site.git, "Uploaded #{file.relative_path}")
					end
				end
			elsif params['folder']
				folder = Tint::Directory.new(site, directory.relative_path.join(params["folder"]))
				return redirect to(folder.route)
			end

			redirect to(directory.route)
		end

		delete "/:site/files/*" do
			file = site.file(params["splat"].join("/"))
			authorize file, :destroy?

			site.git.remove(file.path.to_s)
			commit(site.git, "Removed #{file.relative_path}")

			redirect to(file.parent.route)
		end

	protected

		def render_directory(directory)
			erb :"layouts/files", locals: { directory: directory } do
				erb :"files/index", locals: { directory: directory }
			end
		end

		def process_form_data(data, git)
			case data
			when Array
				data.reject { |v| v.is_a?(String) && v.to_s == "" }.map { |v| process_form_data(v, git) }
			when Hash
				if data.keys.include?(:filename) && data.keys.include?(:tempfile)
					uploads = Tint::Directory.new(site, Pathname.new("uploads").join(Time.now.strftime("%Y")))
					uploads.path.mkpath
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
				if data == ""
					nil
				else
					data
				end
			end
		end

		def is_date?(field_name, value)
			(field_name.end_with?("_date") || field_name == "date") &&
				value.is_a?(String) &&
				value.to_s != ""
		end

		def commit(git, message)
			if pundit_user && pundit_user[:email]
				git.commit("#{message} via tint", author: "#{pundit_user[:fn]} <#{pundit_user[:email]}>")
			else
				git.commit("#{message} via tint")
			end
		end

		def site
			if ENV['SITE_PATH']
				Tint::Site.new(
					site_id: (params['site'] || 1).to_i,
					user_id: 1,
					cache_path: Pathname.new(ENV['SITE_PATH']).realpath,
					fn: "Local Site"
				)
			else
				Tint::Site.new(DB[:sites][site_id: params['site'].to_i])
			end
		end
	end
end
