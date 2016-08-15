require "github_api"

module Tint
	module GitProviders
		class Github
			def initialize(token)
				@github = ::Github.new(oauth_token: token, auto_pagination: true)
			end

			def repositories
				@github.repos.list.select { |repo| repo.permissions.admin }.map do |repo|
					{
						fn: repo.full_name,
						remote: repo.ssh_url,
						link: repo.html_url,
						description: repo.description,
					}
				end
			end
		end
	end
end
