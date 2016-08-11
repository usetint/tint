require "json"
require "shellwords"

require_relative "base"
require_relative "../build_script"
require_relative "../local_job"
require_relative "../travis_job"

module Tint
	module Controllers
		class Build < Base
			post "/script" do
				# Anyone can ask for a build script
				skip_authorization

				payload = JSON.parse(request.body.read.to_s)

				content_type :text
				Tint.build_script(
					payload['job']['id'],
					payload['site']['site_id'],
					payload['site']['remote']
				)
			end

			post "/:site/deploy" do
				# Custom auth in this case because it's a robot not a user
				skip_authorization

				content_type :text

				auth = Rack::Auth::Basic::Request.new(request.env)
				job = BuildJob.get(auth.credentials && auth.credentials.first)
				unless auth.provided? && auth.basic? && auth.credentials && \
				       auth.credentials.last == Tint.token(job.job_id) && \
				       site == job.site && \
				       ![:finished, :passed, :failed, :errored, :cancelled].include?(job.status)
					headers['WWW-Authenticate'] = 'Basic realm="travis"'
					return halt 401, "Not authorized\n"
				end

				Tempfile.open("tint-deploy") do |tmp|
					loop do
						chunk = request.body.read(4096)
						if chunk
							tmp.write chunk
						else
							break
						end
					end

					tmp.flush

					tar = Shellwords.escape(tmp.path)
					deploy_to = Shellwords.escape(job.site.deploy_path.to_s)
					if system("tar --strip-components=1 -xf #{tar} -C #{deploy_to}")
						"OK\n"
					else
						halt 500, "Error deploying\n"
					end
				end
			end

			post "/:site/sync" do
				# No harm in letting anyone rebuild
				# This is also a webhook
				skip_authorization

				Thread.new { site.sync }

				job = site.build

				if job.status == :errored
					slim :error, locals: { message:  "Something went wrong with the build" }
				else
					redirect to(site.route)
				end
			end
		end
	end
end
