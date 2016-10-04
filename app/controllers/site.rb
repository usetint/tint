require "pathname"
require "shellwords"
require "uri"

require_relative "../git_providers/bitbucket"
require_relative "../git_providers/git_providers"
require_relative "../git_providers/github"
require_relative "../git_providers/gitlab"
require_relative "../site"
require_relative "../wordlist"
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

					git_providers = Tint.db[:identities].where(user_id: pundit_user.user_id).map do |identity|
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
					begin
						subdomain = WORDLIST.sample(3).join('-')
						site_id = Tint.db[:sites].insert(
							user_id: pundit_user.user_id,
							fn: params[:fn],
							remote: params[:remote],
							domain: DOMAIN && "#{subdomain}.#{DOMAIN}"
						)
					rescue Sequel::UniqueConstraintViolation
						retry
					end

					if params[:provider]
						identity = Tint.db[:identities][user_id: pundit_user.user_id, provider: params[:provider]]
						if identity && (provider = GitProviders.build(identity[:provider], identity[:omniauth]))
							provider.add_deploy_key(params[:remote], Tint::Site.new(site_id: site_id).ssh_public_key_path.read)
							provider.subscribe(params[:remote], "#{ENV.fetch("APP_URL")}/#{site_id}/sync")
						end
					end

					site_id
				end

				redirect to("/#{site_id}/")
			end

			namespace "/:site" do
				get "/", params: :invite do
					authorize site, :accept_invitation?

					invite = Tint.db[:site_invites].
						where(site_id: params[:site], invite_code: params[:invite]).
						where("expires_at > ?", Time.now.utc).first

					if invite
						Tint.db[:site_users].insert(
							site_id: params[:site].to_i,
							user_id: pundit_user.user_id,
							role: invite[:role]
						)

						redirect(site.route)
					else
						status 404
						slim :error, locals: { message: "Not a valid invite code." }
					end
				end

				get "/" do
					authorize site, :index?

					unless site.git?
						Thread.new { site.clone }
					end

					slim :"site/index", locals: { site: site }
				end

				put "/" do
					authorize site, :update?

					params["domain"] = "#{params[:subdomain]}.#{DOMAIN}" if params[:subdomain]

					updated_attributes = [:fn, :remote, :domain, :show_config_warning].select { |key|
						params.has_key?(key.to_s)
					}.each_with_object({}) { |key, update|
						update[key] = translate(params[key])
					}

					Tint.db[:sites].where(site_id: params[:site]).update(updated_attributes)

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

			namespace "/:site/users" do
				get "/" do
					authorize site, :manage_users?
					users = Tint.db[:users].where(user_id: site.users.map { |u| u[:user_id] }).map do |user|
						role = site.users.find { |u| u[:user_id] == user[:user_id] }
						user.merge(role: role[:role])
					end

					slim :"site/users", locals: {
						site: site,
						users: users,
						owner_invite: invite_for("owner"),
						client_invite: invite_for("client")
					}
				end
			end

		protected

			def invite_for(role)
				invite = Tint.db[:site_invites].
							where(site_id: params["site"].to_i, role: role).
							where("expires_at > ?", Time.now.utc + 432000 - 3600).first
				unless invite
					invite = {
						invite_code: SecureRandom.urlsafe_base64,
						expires_at: Time.now.utc + 432000,
						site_id: params["site"].to_i,
						role: role
					}

					Tint.db[:site_invites].insert(invite)
				end

				invite
			end

			def translate(value)
				case value
				when "false"
					false
				when "true"
					true
				else
					value
				end
			end
		end
	end
end
