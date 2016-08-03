require "active_support/inflector/methods"
require "slim"
require_relative "future"

module Tint
	module Helpers
		module Rendering
			def render_yml(value)
				"#{
				case value
				when Hash
					value.map { |k, v| render_value(k, v, "data[#{k}]") }.join
				when Array
					"<ol data-key='data'>#{value.each_with_index.map { |v, i| "<li>#{render_value(nil, v, "data[#{i}]")}" }.join}</ol>"
				else
					raise TypeError, 'YAML root must be a Hash or Array'
				end
				}<script type='text/javascript' src='/yaml.js'></script>"
			end

			def render_value(key, value, name)
				case value
				when Hash
					return render_slim(
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
					render_checkbox(name, value)
				elsif key.to_s.end_with?("_path")
					render_file(name, value)
				elsif key.to_s.downcase.end_with?("_datetime") || key.to_s.downcase == "datetime" || value.is_a?(Time)
					time = Time.parse(value.to_s) if value.to_s != ""
					render_slim("inputs/datetime", name: name, time: time)
				elsif key.to_s.downcase.end_with?("_date") || key.to_s.downcase == "date"
					date = Date.parse(value.to_s) if value.to_s != ""
					render_slim("inputs/date", name: name, date: date)
				elsif value.is_a?(String) && value.length > 50
					render_slim("inputs/textarea", name: name, value: value)
				elsif key && (options = site.config.dig("options", key))
					render_multiple_select(name, value, options)
				elsif key && (options = site.config.dig("options", ActiveSupport::Inflector.pluralize(key)))
					render_select(name, value, options)
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

			def render_checkbox(name, value)
				render_slim("inputs/checkbox", name: name, value: value)
			end

			def render_file(name, value)
				render_slim("inputs/file", name: name, value: value)
			end

			def render_select(name, value, options)
				render_slim(
					"inputs/select",
					name: name,
					value: value,
					options: format_options(options)
				)
			end

			def render_multiple_select(name, value, options)
				return render_slim(
					"inputs/multiple_select",
					name: name,
					value: Array(value),
					options: format_options(options)
				)
			end

			def multiple_select?(key)
				!!site.config.dig("options", key)
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
					self.class.send(:define_method, key) { value }
				end
			end
		end
	end
end
