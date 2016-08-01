require 'active_support/inflector/methods'

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
					"<fieldset#{" class='hidden'" if key.to_s.start_with?("_")}>#{"<legend>#{key}</legend>" if key}#{
					value.map do |key, value|
						"#{render_value(key, value, "#{name}[#{key}]")}"
					end.join
					}</fieldset>"
				when Array
					if multiple_select?(key)
						render_input(key, value, name)
					else
						"<fieldset#{" class='hidden'" if key.to_s.start_with?("_")}><legend>#{key}</legend><ol data-key='#{name}'>#{
							value.each_with_index.map { |v, i| "<li>#{render_value(nil, v, "#{name}[#{i}]")}</li>" }.join
						}</ol></fieldset>"
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
					time = Time.parse(value.to_s) if value.strip != ""
					"
						<input type='date' name='#{name}[___datetime_date]' value='#{time && time.strftime("%F")}' />
						<input type='time' name='#{name}[___datetime_time]' value='#{time && time.strftime("%H:%M:%S")}' />
					"
				elsif key.to_s.downcase.end_with?("_date") || key.to_s.downcase == "date"
					date = Date.parse(value.to_s) if value.strip != ""
					"<input type='date' name='#{name}' value='#{date && date.strftime("%F")}' />"
				elsif value.is_a?(String) && value.length > 50
					"<textarea name='#{name}'>#{value}</textarea>"
				elsif key && (options = PROJECT_CONFIG["options"][ActiveSupport::Inflector.pluralize(key)])
					render_select(name, value, options)
				elsif key && (options = PROJECT_CONFIG["options"][key])
					render_multiple_select(name, value, options)
				else
					"<input type='text' name='#{name}' value='#{value}' />"
				end

				if key
					"<label#{" class='hidden'" if key.to_s.start_with?("_")}>#{key} #{input}</label>"
				else
					input
				end
			end

		protected

			def render_checkbox(name, value)
				"
					<input type='hidden' name='#{name}[___checkbox_unchecked]' value='' />
					<input type='checkbox' name='#{name}[___checkbox_checked]' #{' checked="checked"' if value} />
				"
			end

			def render_file(name, value)
				"
					<div class='value'>#{value}</div>
					<input type='hidden' name='#{name}' value='#{value}' />
					<input type='file' name='#{name}' />
				"
			end

			def render_select(name, value, options)
				"
					<select name='#{name}'>
						<option></option>
						#{
						if options.is_a? Hash
							options.map { |k, v| render_option(k, v, k == value) }.join
						elsif options.is_a? Array
							options.map { |v| render_option(v, v, v == value) }.join
						end
						}
					</select>
				"
			end

			def render_multiple_select(name, value, options)
				"
					<input type='hidden' name='#{name}[]' />
					<select name='#{name}[]' multiple='multiple'>
						#{
						if options.is_a? Hash
							options.map { |k, v| render_option(k, v, value.include?(k)) }.join
						elsif options.is_a? Array
							options.map { |v| render_option(v, v, value.include?(v)) }.join
						end
						}
					</select>
				"
			end

			def render_option(value, fv, selected)
				"<option value='#{value}'#{ "selected='selected'" if selected}>#{fv}</option>"
			end

			def multiple_select?(key)
				!!PROJECT_CONFIG["options"][key]
			end
		end
	end
end
