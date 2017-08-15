require "gitlab"
require "json"

module Tint
	module GitProviders
		class Gitlab
			attr_reader :nickname

			def initialize(payload)
				omniauth = JSON.parse(payload)
				@gitlab = ::Gitlab.client(
					endpoint: "#{omniauth["site"]}/api/v3",
					private_token: omniauth["credentials"]["token"]
				)
				@nickname = omniauth["info"]["username"]
			end

			def valid?
				!!@gitlab.user
			rescue ::Gitlab::Error::Unauthorized
			end

			def repositories(exclude: [])
				@gitlab.projects(archived: false).auto_paginate.select { |repo|
					!exclude.include?(repo.ssh_url_to_repo)
				}.map do |repo|
					{
						fn: repo.name_with_namespace,
						remote: repo.ssh_url_to_repo,
						link: repo.web_url,
						description: repo.description
					}
				end
			end

			def add_deploy_key(_remote, public_key)
				# We just add to the user for now, because there are no read/write
				# deploy keys in Gitlab
				# https://gitlab.com/gitlab-org/gitlab-ce/issues/19658
				@gitlab.create_ssh_key(
					"tint",
					public_key
				)
			rescue ::Gitlab::Error::BadRequest => e
				raise e unless e.message =~ /'fingerprint' has already been taken/
			end

			def subscribe(remote, callback)
				user, repo = GitProviders.extract_from_remote(remote)
				@gitlab.add_project_hook(
					"#{user}%2F#{repo}",
					callback,
					push_events: 1
				)
			end
		end
	end
end
