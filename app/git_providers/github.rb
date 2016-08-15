require "http_link_header"
require "json"
require "net/http"
require "uri"

module Tint
	module GitProviders
		class Github
			def initialize(token)
				@token = token
			end

			def repositories
				next_page = "/user/repos"
				results = []

				while next_page
					next_page, page = repositories_page(next_page)
					results += page
				end

				results
			end

		protected

			def repositories_page(uri)
				resp = request("GET", uri, per_page: 100)
				raise resp unless resp.is_a?(Net::HTTPOK)
				next_page = HttpLinkHeader.new(resp["Link"]).rel("next")
				[
					next_page && URI(next_page),
					JSON.parse(resp.body).map do |repo|
						{
							fn: repo["full_name"],
							remote: repo["ssh_url"],
							link: repo["html_url"],
							description: repo["description"],
						}
					end
				]
			end

			def request(method, uri_or_path, params=nil)
				uri = uri_or_path.is_a?(URI) ? uri_or_path : URI("https://api.github.com#{uri_or_path}")

				if params && ["GET", "HEAD"].include?(method)
					uri.query = "#{uri.query}&#{URI.encode_www_form(params)}"
					params = nil
				end

				req = Net::HTTPGenericRequest.new(
					method,
					!["GET", "HEAD"].include?(method),
					!["HEAD"].include?(method),
					uri,
					"User-Agent" => "Tint",
					"Authorization" => "token #{@token}"
				)

				req.form_data = params if params

				Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
					http.request(req)
				end
			end
		end
	end
end
