require "digest"
require "github_api"
require "json"

module Tint
	module GitProviders
		class Github
			attr_reader :nickname

			def initialize(payload)
				payload = JSON.parse(payload)
				token = payload["credentials"]["token"]
				@github = ::Github.new(oauth_token: token, per_page: 100, auto_pagination: true)
				@nickname = payload["info"]["nickname"]
			end

			def valid?
				!!@github.users.get
			rescue ::Github::Error::Unauthorized
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

			def add_deploy_key(remote, public_key)
				user, repo = GitProviders.extract_from_remote(remote)
				@github.repos.keys.create(
					user: user,
					repo: repo,
					key: public_key,
					title: "tint",
					read_only: false
				)
			rescue ::Github::Error::UnprocessableEntity => e
				raise e unless e.data[:errors].find { |err| err[:message] == "key is already in use" }
			end

			def subscribe(remote, callback)
				user, repo = GitProviders.extract_from_remote(remote)
				@github.repos.pubsubhubbub.subscribe(
					"https://github.com/#{user}/#{repo}/events/push",
					callback,
					verify: 'sync',
					secret: Digest::SHA256.hexdigest("github#{ENV.fetch('SESSION_SECRET')}")
				)
			end
		end
	end
end
