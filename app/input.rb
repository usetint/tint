module Tint
	module Input
		def self.multiple_select_options(site, key)
			site.config.dig("options", key)
		end

		class Base
			attr_reader :key, :name, :value, :site

			def initialize(key, name, value, site)
				@key = key
				@name = name
				@value = value
				@site = site
			end

			def self.build(key, name, value, site, type=nil)
				if type
					class_for(type).new(key, name, value, site)
				else
					auto_class(key, name, value, site).new(key, name, value, site)
				end
			end

			def self.auto_class(key, name, value, site)
				if [true, false].include? value
					Checkbox
				elsif key.to_s.end_with?("_path")
					File
				elsif key.to_s.downcase.end_with?("_datetime") || key.to_s.downcase == "datetime" || value.is_a?(Time)
					DateTime
				elsif key.to_s.downcase.end_with?("_date") || key.to_s.downcase == "date"
					Date
				elsif value.is_a?(String) && value.length > 50
					Textarea
				elsif Tint::Input.multiple_select_options(site, key)
					MultipleSelect
				elsif key && site.config.dig("options", ActiveSupport::Inflector.pluralize(key))
					Select
				else
					Text
				end
			end

			def self.class_for(type)
				{
					file: File,
					checkbox: Checkbox,
					datetime: DateTime,
					date: Date,
					textarea: Textarea,
					multiple_select: MultipleSelect,
					select: Select,
					text: Text
				}.fetch(type)
			end

			def render
				Slim::Template.new("app/views/inputs/#{template}.slim").render(self)
			end
		end

		class Checkbox < Base
			def template
				:checkbox
			end
		end

		class File < Base
			def file
				Tint::File.new(site, value)
			end

			def encoded_image
				file.encoded_image
			end

			def template
				:file
			end
		end

		class DateTime < Base
			def time
				Time.parse(value.to_s) if value.to_s != ""
			end

			def template
				:datetime
			end
		end

		class Date < Base
			def date
				::Date.parse(value.to_s) if value.to_s != ""
			end

			def template
				:date
			end
		end

		class Textarea < Base
			def template
				:textarea
			end
		end

		class Select < Base
			def options
				format_options(site.config.dig("options", ActiveSupport::Inflector.pluralize(key)))
			end

			def template
				:select
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
				format_options(Input.multiple_select_options(site, key))
			end

			def template
				:multiple_select
			end
		end

		class Text < Base
			def template
				:text
			end
		end
	end
end
