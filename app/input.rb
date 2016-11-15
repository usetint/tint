require "active_support/inflector/methods"
require "ruby_dig"

module Tint
	module Input
		def self.select_options(site, key)
			site.config.dig("options", key)
		end

		def self.type(key, value, site)
			return unless scalarish?(value)

			norm_key = key.to_s.downcase
			if select_options(site, key)
				MultipleSelect
			elsif select_options(site, ActiveSupport::Inflector.pluralize(key.to_s))
				Select
			elsif [true, false].include? value
				Checkbox
			elsif ["_path", "_paths"].any? { |x| norm_key.end_with?(x) }
				File
			elsif ["_datetime", "_datetimes"].any? { |x| norm_key.end_with?(x) || norm_key == x[1..-1] } || value.is_a?(::Time)
				DateTime
			elsif ["_date", "_dates"].any? { |x| norm_key.end_with?(x) || norm_key == x[1..-1] } || value.is_a?(::Date)
				Date
			elsif ["_time", "_times"].any? { |x| norm_key.end_with?(x) || norm_key == x[1..-1] }
				Time
			elsif norm_key == "description" || norm_key.end_with?("_text") || (value.is_a?(String) && value.length > 50)
				Textarea
			else
				Text
			end
		end

		def self.scalarish?(value)
			!value.is_a?(Enumerable) || (value.is_a?(Array) && value.all? { |v| !v.is_a?(Enumerable) })
		end

		Base = Struct.new(:key, :name, :value, :site) do
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
				Tint::File.new(site, value) if value
			end
		end

		class DateTime < Base
			def value
				::Time.parse(super.to_s) if super.to_s != ""
			end
		end

		class Date < Base
			def value
				::Date.parse(super.to_s) if super.to_s != ""
			end
		end

		class Time < Base
		end

		class Select < Base
			def options
				format_options(
					Input.select_options(site, option_key)
				).map do |v, d|
					[v, d, Array(value).map(&:to_s).include?(v.to_s)]
				end
			end

		protected

			def option_key
				ActiveSupport::Inflector.pluralize(key.to_s)
			end

			def format_options(options)
				case options
				when Array
					options.map { |value| [value, value] }
				when Hash
					options.map { |value, display| [value, display] }
				when Site::Config::Basenames
					format_options(site.resource(options).children(false).map { |file|
						file.basename(file.extname).to_s
					})
				when String # Filenames
					format_options(site.resource(options).children(false).map(&:fn))
				else
					fail ArgumentError, "options must be a Hash or an Array"
				end
			end
		end

		class MultipleSelect < Select
			def value
				Array(super)
			end

		protected

			def option_key
				key.to_s
			end
		end
	end
end
