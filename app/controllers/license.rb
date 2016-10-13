require_relative "base"

module Tint
	module Controllers
		class License < Base
			get "/license" do
				skip_authorization
				slim :license
			end
		end
	end
end
