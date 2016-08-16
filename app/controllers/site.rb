require "pathname"
require "shellwords"

require_relative "base"
require_relative "../site"
require_relative "../git_providers/github"

module Tint
	module Controllers
		class Site < Base
			get "/" do
				if ENV['SITE_PATH']
					authorize site, :index?
					slim :"site/index", locals: { site: site }
				else
					authorize Tint::Site, :index?

					git_providers = DB[:identities].where(user_id: pundit_user[:user_id]).map do |identity|
						if identity[:provider] == "github"
							GitProviders::Github.new(identity[:omniauth])
						end
					end.compact

					sites = policy_scope(Tint::Site)
					repos = sites.map { |site| site.remote }

					slim :index, locals: { sites: sites, repos: repos, git_providers: git_providers }
				end
			end

			post "/" do
				authorize Tint::Site, :create?

				if params[:provider] == "github"
					identity = DB[:identities][user_id: pundit_user[:user_id], provider: "github"]
					GitProviders::Github.new(identity[:omniauth]).add_deploy_key(params[:remote])
				end

				site_id = DB[:sites].insert(
					user_id: pundit_user[:user_id],
					fn: params[:fn],
					remote: params[:remote]
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
			end
		end
	end
end
