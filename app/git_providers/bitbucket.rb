require "json"
require "httparty"

module Tint
	module GitProviders
		class Bitbucket
			include HTTParty

			base_uri "https://api.bitbucket.org/2.0"

			def initialize(payload)
				@omniauth = JSON.parse(payload)
			end

			def repositories(exclude: [])
				get_repositories.reject { |repo|
					repo["scm"] != "git" || Array(exclude).include?(remote(repo))
				}.map { |repo|
					{
						fn: repo["name"],
						remote: remote(repo),
						link: repo["links"]["html"],
						description: repo["description"]
					}
				}
			end

			def add_deploy_key(remote)
			end

			def subscribe(remote, callback)
				user, repo = extract_from_remote(remote)
				self.class.post(
					"/repositories/#{user}/#{repo}/hooks",
					body: {
						url: callback,
						active: true,
						events: ["repo:push"]
					}.to_json,
					headers: {
						"Authorization" => "Bearer #{omniauth["credentials"]["token"]}",
						"Content-Type" => "application/json"
					}
				)
			end

		protected

			attr_reader :omniauth

			def remote(repo)
				repo["links"]["clone"].find { |link| link["name"] == "ssh" }["href"]
			end

			def get_repositories(repos=[], path="/repositories/#{omniauth["uid"]}?pagelen=100")
				response = self.class.get(path, headers: {
					"Authorization" => "Bearer #{omniauth["credentials"]["token"]}"
				})

				repos = repos + response["values"]
				if response["next"]
					get_repositories(repos, response["next"])
				else
					repos
				end
			end

			def extract_from_remote(remote)
				match_data = remote.match(/bitbucket\.org\/([^\/]+)\/(.+)\.git$/)
				[match_data[1], match_data[2]]
			end
		end
	end
end
