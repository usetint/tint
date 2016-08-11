require "json"

require_relative "base"
require_relative "../build_script"

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
		end
	end
end
