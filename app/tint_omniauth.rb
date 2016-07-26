# From http://stackoverflow.com/a/13113846/8611
# Allows us to get a list of used providers
module OmniAuth
	class Builder < ::Rack::Builder
		def provider_patch(klass, *args, &block)
			@@providers ||= []
			@@providers << klass
			old_provider(klass, *args, &block)
		end
		alias old_provider provider
		alias provider provider_patch
		class << self
			def providers
				if class_variables.include?(:@@providers)
					@@providers
				else
					[]
				end
			end
		end
	end
end
