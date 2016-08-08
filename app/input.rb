module Tint
	module Input
		def self.select_options(site, key)
			site.config.dig("options", key)
		end

		def self.type(key, value, site)
			return unless scalarish?(value)

			if [true, false].include? value
				Checkbox
			elsif key.to_s.end_with?("_path") || key.to_s.end_with?("_paths")
				File
			elsif key.to_s.downcase.end_with?("_datetime") || key.to_s.downcase == "datetime" || value.is_a?(Time)
				DateTime
			elsif key.to_s.downcase.end_with?("_date") || key.to_s.downcase == "date"
				Date
			elsif select_options(site, key)
				MultipleSelect
			elsif select_options(site, ActiveSupport::Inflector.pluralize(key.to_s))
				Select
			elsif value.is_a?(String) && value.length > 50
				Textarea
			else
				Text
			end
		end

		def self.scalarish?(value)
			!value.is_a?(Enumerable) || (value.is_a?(Array) && value.map { |v| !value.is_a?(Enumerable) })
		end

		def self.build(key, name, value, site, type=nil)
			type ||= type(key, value, site)
			type.new(name, value, site, select_options(site, ActiveSupport::Inflector.pluralize(key.to_s)))
		end

		class Base
			attr_reader :name, :value, :site, :options

			def initialize(name, value, site, options=nil)
				@name = name
				@value = value
				@site = site
				@options = options
			end

			def render
				Slim::Template.new("app/views/inputs/#{template}.slim").render(self)
			end

			def template
				self.class.name.downcase.split("::").last
			end
		end

		class Checkbox < Base
		end

		class Text < Base
		end

		class Textarea < Base
		end

		class File < Base
			def file
				Tint::File.new(site, value)
			end

			def encoded_image
				Base64.encode64(file.path.open.read) if file.image? && file.size / 2**20 < 10
			end
		end

		class DateTime < Base
			def value
				Time.parse(super.to_s) if super.to_s != ""
			end
		end

		class Date < Base
			def value
				::Date.parse(super.to_s) if super.to_s != ""
			end
		end

		class Select < Base
			def options
				format_options(@options)
			end

		protected

			def format_options(options)
				if options.is_a? Array
					options.map { |value| [value, value] }
				elsif options.is_a? Hash
					options.map { |value, display| [value, display] }
				else
					fail ArgumentError, "options must be a Hash or an Array"
				end
			end
		end

		class MultipleSelect < Select
			def value
				Array(@value)
			end

			def options
				format_options(@options)
			end
		end
	end
end
