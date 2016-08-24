require "sinatra"
require "sinatra/namespace"
require "sinatra/pundit"
require "sinatra/reloader"
require "sinatra/respond_with"
require "sinatra/streaming"

require "slim"

require_relative "../db"
require_relative "../helpers"
require_relative "../site"
require_relative "../user"

module Tint
	module Controllers
		class Base < Sinatra::Base
			set :root, Pathname.new(__FILE__).dirname.dirname

			configure :development do
				set :show_exceptions, :after_handler
			end

			register Sinatra::Pundit
			register Sinatra::Namespace
			register Sinatra::RespondWith
			helpers Sinatra::Streaming
			helpers Tint::Helpers::Rendering

			error Pundit::NotAuthorizedError do
				redirect to("/auth/login")
			end

			enable :sessions
			set :session_secret, ENV["SESSION_SECRET"]
			set :method_override, true

			current_user do
				if ENV['SITE_PATH']
					User.new(user_id: 1)
				else
					User.new(Tint.db[:users][user_id: session["user"].to_i]) if session["user"]
				end
			end

			before do
				blank_is_nil!(params)
			end

			after do
				verify_authorized
			end

			def self.params(key)
				condition { !!params[key] }
			end

		protected

			def site
				if ENV['SITE_PATH']
					LocalJob.local_site(params['site'])
				else
					Tint::Site.new(Tint.db[:sites][site_id: params['site'].to_i])
				end
			end

			def blank_is_nil!(hash)
				hash.each do |k, v|
					case v
					when Hash
						blank_is_nil!(v)
					when Array
						hash[k] = v.map { |x| x.to_s == "" ? nil : x }
					else
						hash[k] = nil if v.to_s == ""
					end
				end
			end
		end
	end
end
