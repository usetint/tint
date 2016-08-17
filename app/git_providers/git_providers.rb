module Tint
	module GitProviders
		def self.build(provider, omniauth)
			provider = constants.find { |p| p.to_s.downcase == provider }
			const_get(provider).new(omniauth) if provider
		end

		# Based on how many remotes are formatted
		def self.extract_from_remote(remote)
			match_data = remote.match(/:([^\/]+)\/(.+)\.git$/)
			[match_data[1], match_data[2]]
		end
	end
end
