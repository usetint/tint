require "slim"
require_relative "input"

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

			def render_value(key, value, name, type=nil, legend=nil)
				case value
				when Hash
					render_slim(
						"inputs/fieldset/hash",
						legend: key,
						name: name,
						value: value
					)
				when Array
					input_type = Input.type(key, value, site)

					if input_type == Input::MultipleSelect
						render_input(key, value, name, type)
					else
						value = [nil] if value.length < 1

						render_slim(
							"inputs/fieldset/array",
							legend: key,
							name: name,
							value: value,
							type: input_type
						)
					end
				else
					render_input(key, value, name, type, legend)
				end
			end

			def render_input(key, value, name, type=nil, legend=nil)
				type ||= Input.type(key, value, site)
				input = type.new(key || legend, name, value, site).render

				if key
					render_slim("inputs/labelled", label: key, input: input)
				else
					input
				end
			end

			def render_log(log:, route:, button:)
				render_slim :log, log: log, route: route, button: button
			end

			def localtime(time, fmt="%F %H:%M")
				return unless time
				render_slim("time", time: time, fmt: fmt)
			end

		protected

			def render_slim(template, locals)
				Slim::Template.new("app/views/#{template}.slim").render(
					Scope.new(locals.merge(site: site))
				)
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

# Monkypatch to allow digging into session

require "rack/session/abstract/id"

class Rack::Session::Abstract::SessionHash
	def dig(*args)
		to_hash.dig(*args)
	end
end
