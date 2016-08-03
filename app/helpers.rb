require "active_support/inflector/methods"
require "slim"
require_relative "future"

module Tint
	module Helpers
		module Rendering
			def render_yml(value)
				case value
				when Hash
					template = "inputs/hash"
				when Array
					template = "inputs/array"
				else
					raise TypeError, 'YAML root must be a Hash or Array'
				end

				render_slim("inputs/yaml", template: template, value: value)
			end

			def render_value(key, value, name)
				case value
				when Hash
					render_slim(
						"inputs/fieldset/hash",
						legend: key,
						name: name,
						value: value
					)
				when Array
					if multiple_select?(key)
						render_input(key, value, name)
					else
						render_slim(
							"inputs/fieldset/array",
							legend: key,
							name: name,
							value: value
						)
					end
				else
					render_input(key, value, name)
				end
			end

			def render_input(key, value, name)
				input = if [true, false].include? value
					render_slim("inputs/checkbox", name: name, value: value)
				elsif key.to_s.end_with?("_path")
					render_slim("inputs/file", name: name, value: value)
				elsif key.to_s.downcase.end_with?("_datetime") || key.to_s.downcase == "datetime" || value.is_a?(Time)
					time = Time.parse(value.to_s) if value.to_s != ""
					render_slim("inputs/datetime", name: name, time: time)
				elsif key.to_s.downcase.end_with?("_date") || key.to_s.downcase == "date"
					date = Date.parse(value.to_s) if value.to_s != ""
					render_slim("inputs/date", name: name, date: date)
				elsif value.is_a?(String) && value.length > 50
					render_slim("inputs/textarea", name: name, value: value)
				elsif key && (options = site.config.dig("options", key))
					render_slim("inputs/multiple_select", name: name, value: Array(value), options: format_options(options))
				elsif key && (options = site.config.dig("options", ActiveSupport::Inflector.pluralize(key)))
					render_slim("inputs/select", name: name, value: value, options: format_options(options))
				else
					render_slim("inputs/text", name: name, value: value)
				end

				if key
					render_slim("inputs/labelled", label: key, input: input)
				else
					input
				end
			end

		protected

			def render_slim(template, locals)
				Slim::Template.new("app/views/#{template}.slim").render(
					Scope.new(locals.merge(site: site))
				)
			end

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

		class Scope
			include Rendering

			def initialize(locals)
				locals.each do |key, value|
					define_singleton_method(key) { value }
				end
			end
		end
	end
end
