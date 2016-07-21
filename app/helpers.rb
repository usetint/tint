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
					"<fieldset#{" class='hidden'" if key.to_s.start_with?("_")}><legend>#{key}</legend><ol data-key='#{name}'>#{
						value.each_with_index.map { |v, i| "<li>#{render_value(nil, v, "#{name}[#{i}]")}</li>" }.join
					}</ol></fieldset>"
				else
					render_input(key, value, name)
				end
			end

			def render_input(key, value, name)
				input = if [true, false].include? value
					"
						<input type='hidden' name='#{name}[___checkbox_unchecked]' value='' />
						<input type='checkbox' name='#{name}[___checkbox_checked]' #{' checked="checked"' if value} />
					"
				elsif key.end_with?("_path")
					"
						<div class='value'>#{value}</div>
						<input type='hidden' name='#{name}' value='#{value}' />
						<input type='file' name='#{name}' />
					"
				elsif value.is_a?(String) && value.length > 50
					"<textarea name='#{name}'>#{value}</textarea>"
				else
					"<input type='text' name='#{name}' value='#{value}' />"
				end

				if key
					"<label#{" class='hidden'" if key.to_s.start_with?("_")}>#{key} #{input}</label>"
				else
					input
				end
			end
		end
	end
end
