require "json"
require "httparty"

module Tint
	module GitProviders
		class Bitbucket
			include HTTParty

			base_uri "https://api.bitbucket.org"

			def initialize(payload)
				@omniauth = JSON.parse(payload)
			end

			def repositories(exclude: [])
				repos = self.class.get("/2.0/repositories/#{omniauth["uid"]}", headers: {
					"Authorization" => "Bearer #{omniauth["credentials"]["token"]}"
				})

				repos["values"].select { |r| r["scm"] == "git" }.map do |repo|
					{
						fn: repo["name"],
						remote: repo["links"]["clone"].find { |link| link["name"] == "ssh" }["href"],
						link: repo["links"]["html"],
						description: repo["description"]
					}
				end
			end

			def add_deploy_key(remote)
			end

			def subscribe(remote, callback)
			end

		protected

			attr_reader :omniauth
		end
	end
end
