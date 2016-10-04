require "sass"
require "sprockets"
require "skim"

require_relative "base"

module Tint
	module Controllers
		class Asset < Controllers::Base
			set :sprockets, Sprockets::Environment.new
			sprockets.append_path "assets/stylesheets"
			sprockets.append_path "assets/javascripts"
			sprockets.append_path "assets/images"

			get "/assets/*" do
				skip_authorization
				env["PATH_INFO"].sub!("/assets", "")
				settings.sprockets.call(env)
			end
		end
	end
end
