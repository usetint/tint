require "omniauth"
require "omniauth-github"
require "omniauth-indieauth"

require_relative "base"
require_relative "../tint_omniauth" # Monkeypatch

module Tint
	module Controllers
		class Auth < Base
			use OmniAuth::Builder do
				if ENV['GITHUB_KEY']
					provider :github, ENV['GITHUB_KEY'], ENV['GITHUB_SECRET'], scope: "user,repo,write:repo_hook"
				end

				if ENV['APP_URL']
					provider :indieauth, client_id: ENV['APP_URL']
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

					identity = DB[:identities][provider: params[:provider], uid: request.env["omniauth.auth"].uid]

					if identity
						DB[:identities].where(provider: params[:provider], uid: request.env["omniauth.auth"].uid).
							update(omniauth: request.env["omniauth.auth"].to_json)
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
			end
		end
	end
end
