require "github_api"
require "json"

module Tint
	module GitProviders
		class Github
			def initialize(payload)
				token = JSON.parse(payload)["credentials"]["token"]
				@github = ::Github.new(oauth_token: token, per_page: 100, auto_pagination: true)
			end

			def repositories(exclude: [])
				@github.repos.list.select { |repo|
					repo.permissions.admin && !exclude.include?(repo.ssh_url)
				}.map do |repo|
					{
						fn: repo.full_name,
						remote: repo.ssh_url,
						link: repo.html_url,
						description: repo.description,
					}
				end
			end

			def add_deploy_key(remote)
				match_data = remote.match(/github\.com:([^\/]+)\/(.+)\.git$/)
				@github.repos.keys.create(
					user: match_data[1],
					repo: match_data[2],
					key: ENV.fetch("SSH_PUBLIC"),
					title: "tint",
					read_only: false
				)
			rescue ::Github::Error::UnprocessableEntity => e
				raise e unless e.data[:errors].find { |err| err[:message] == "key is already in use" }
			end
		end
	end
end
