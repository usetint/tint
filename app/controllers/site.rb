require "pathname"
require "shellwords"

require_relative "../git_providers/git_providers"
require_relative "../git_providers/github"
require_relative "../git_providers/gitlab"
require_relative "../site"
require_relative "base"

module Tint
	module Controllers
		class Site < Base
			get "/" do
				if ENV['SITE_PATH']
					authorize site, :index?
					slim :"site/index", locals: { site: site }
				else
					authorize Tint::Site, :index?

					git_providers = Tint.db[:identities].where(user_id: pundit_user[:user_id]).map do |identity|
						GitProviders.build(identity[:provider], identity[:omniauth])
					end.compact

					sites = policy_scope(Tint::Site)
					repos = sites.map { |site| site.remote }

					slim :index, locals: { sites: sites, repos: repos, git_providers: git_providers }
				end
			end

			post "/" do
				authorize Tint::Site, :create?

				site_id = Tint.db.transaction do
					site_id = Tint.db[:sites].insert(
						user_id: pundit_user[:user_id],
						fn: params[:fn],
						remote: params[:remote]
					)

					if params[:provider]
						identity = Tint.db[:identities][user_id: pundit_user[:user_id], provider: params[:provider]]
						if identity && (provider = GitProviders.build(identity[:provider], identity[:omniauth]))
							provider.add_deploy_key(params[:remote])
							provider.subscribe(params[:remote], "#{ENV.fetch("APP_URL")}/#{site_id}/sync")
						end
					end

					site_id
				end

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

					Tint.db[:sites].where(site_id: params[:site]).update(
						fn: params[:fn],
						remote: params[:remote],
					)

					site.clear_cache!

					redirect to(site.route)
				end

				delete "/" do
					authorize site, :destroy?

					site.clear_cache!
					Tint.db[:sites].where(site_id: params[:site]).delete

					redirect to("/")
				end
			end
		end
	end
end
