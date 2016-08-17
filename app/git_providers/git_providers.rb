module Tint
	module GitProviders
		def self.build(provider, omniauth)
			provider = constants.find { |p| p.to_s.downcase == provider }
			const_get(provider).new(omniauth) if provider
		end
	end
end
