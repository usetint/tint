require "omniauth"
require "omniauth-bitbucket"
require "omniauth-github"
require "omniauth-gitlab"
require "omniauth-indieauth"

require_relative "../future"
require_relative "../tint_omniauth" # Monkeypatch
require_relative "base"

module Tint
	module Controllers
		class Auth < Base
			use OmniAuth::Builder do
				if ENV['GITHUB_KEY']
					provider :github, ENV['GITHUB_KEY'], ENV['GITHUB_SECRET'], scope: "user,repo,write:repo_hook"
				end

				if ENV["BITBUCKET_KEY"]
					provider :bitbucket, ENV["BITBUCKET_KEY"], ENV["BITBUCKET_SECRET"]
				end

				if ENV['APP_URL']
					provider :indieauth, client_id: ENV['APP_URL']

					provider :gitlab, redirect_url: "#{ENV['APP_URL']}/auth/gitlab/callback", setup: ->(env) {
						if env.dig("rack.request.form_hash", "site")
							if !env.dig("rack.request.form_hash", "client_id") && env.dig("rack.request.form_hash", "site") == ENV["GITLAB_SITE"]
								env["rack.request.form_hash"]["client_id"] = ENV["GITLAB_CLIENT_ID"]
								env["rack.request.form_hash"]["client_secret"] = ENV["GITLAB_CLIENT_SECRET"]
							end

							env['omniauth.strategy'].options[:client_id] = env.dig("rack.request.form_hash", "client_id")
							env['omniauth.strategy'].options[:client_secret] = env.dig("rack.request.form_hash", "client_secret")
							env['omniauth.strategy'].options[:site] = env.dig("rack.request.form_hash", "site")
						else
							env['omniauth.strategy'].options[:client_id] = env.dig("rack.session", "omniauth.params", "client_id")
							env['omniauth.strategy'].options[:client_secret] = env.dig("rack.session", "omniauth.params", "client_secret")
							env['omniauth.strategy'].options[:site] = env.dig("rack.session", "omniauth.params", "site")
						end
					}
				end
			end

			namespace "/auth" do
				get "/login" do
					skip_authorization
					slim :login
				end

				delete "/login" do
					skip_authorization
					session['user'] = nil
					redirect to("/")
				end

				get "/:provider/callback" do
					skip_authorization

					omniauth = request.env["omniauth.params"]
					uid = request.env["omniauth.auth"].uid

					if params[:provider] == "gitlab"
						uid = "#{omniauth["site"]}:#{uid}"
						request.env["omniauth.auth"].merge!(site: omniauth["site"])
					end

					identity = Tint.db[:identities][provider: params[:provider], uid: uid]

					if identity
						if pundit_user
							status 400
							return slim :error, locals: { message: "That identity is claimed by another account." }
						end

						Tint.db[:identities].where(provider: params[:provider], uid: uid).
							update(omniauth: request.env["omniauth.auth"].to_json)
						session["user"] = identity[:user_id]
					else
						unless pundit_user
							session['user'] = Tint.db[:users].insert(
								fn: request.env["omniauth.auth"].info.name,
								email: request.env["omniauth.auth"].info.email
							)
						end

						Tint.db[:identities].insert(
							provider: params["provider"],
							uid: uid,
							omniauth: request.env["omniauth.auth"].to_json,
							user_id: session["user"]
						)
					end

					if session["back_to"]
						redirect session.delete("back_to")
					else
						redirect to("/")
					end
				end
			end
		end
	end
end
