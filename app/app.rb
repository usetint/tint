require "json"
require "pathname"
require "sass"
require "sequel"
require "shellwords"
require "sprockets"

require_relative "site"
require_relative "controllers/base"

ENV["GIT_COMMITTER_NAME"] = "Tint"
ENV["GIT_COMMITTER_EMAIL"] = "commit@usetint.com"

module Tint
	DB = Sequel.connect(ENV.fetch("DATABASE_URL")) unless ENV['SITE_PATH']

	class App < Controllers::Base
		set :sprockets, Sprockets::Environment.new
		sprockets.append_path "assets/stylesheets"
		sprockets.css_compressor = :scss

		get "/assets/*" do
			skip_authorization
			env["PATH_INFO"].sub!("/assets", "")
			settings.sprockets.call(env)
		end

		get "/" do
			if ENV['SITE_PATH']
				authorize site, :index?
				slim :"site/index", locals: { site: site }
			else
				authorize Tint::Site, :index?
				slim :index, locals: { sites: policy_scope(Tint::Site) }
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

		namespace "/:site" do
			get "/" do
				authorize site, :index?

				unless site.git?
					Thread.new { site.clone }
				end

				slim :"site/index", locals: { site: site }
			end

			put "/" do
				authorize site, :update?

				DB[:sites].where(site_id: params[:site]).update(
					fn: params[:fn],
					remote: params[:remote],
				)

				site.clear_cache!

				redirect to(site.route)
			end

			delete "/" do
				authorize site, :destroy?

				site.clear_cache!
				DB[:sites].where(site_id: params[:site]).delete

				redirect to("/")
			end

			post "/sync" do
				# No harm in letting anyone rebuild
				# This is also a webhook
				skip_authorization

				site.sync

				prefix = Pathname.new(ENV["PREFIX"])
				prefix.mkpath
				prefix = Shellwords.escape(prefix.realpath.to_s)
				project = Shellwords.escape(site.cache_path.to_s)
				success = system("env -i - PATH=\"#{ENV['PATH']}\" GEM_PATH=\"#{ENV['GEM_PATH']}\" /bin/sh -c 'cd #{project} && make PREFIX=#{prefix} && make install PREFIX=#{prefix}'")
				if success
					redirect to("/")
				else
					slim :error, locals: { message:  "Something went wrong with the build" }
				end
			end
		end
	end
end
