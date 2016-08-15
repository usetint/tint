module Tint
	module FormHelpers
		def self.process(data, dir)
			case data
			when Array
				data.reject { |v| v.is_a?(String) && v.to_s == "" }.map { |v| process(v, dir) }
			when Hash
				if data.keys.include?(:filename) && data.keys.include?(:tempfile)
					uploads = dir.join("uploads").join(Time.now.strftime("%Y"))
					filename = "#{SecureRandom.uuid}-#{data[:filename]}"
					upload(uploads, data, filename)
					uploads.join(filename).relative_path_from(dir).to_s
				elsif data.keys.include?('___checkbox_unchecked')
					data.keys.include?('___checkbox_checked')
				elsif data.keys.include?("___datetime_date")
					datetime = "#{data["___datetime_date"]} #{data["___datetime_time"]}"
					Time.parse(datetime) if datetime.strip.to_s != ""
				elsif data.keys.all? { |k| k =~ /\A\d+\Z/ }
					data.to_a.sort_by {|x| x.first.to_i }.map(&:last).map { |v| process(v, dir) }
				else
					data.merge(data) do |k,v|
						v = Date.parse(v) if is_date?(k, v)
						process(v, dir)
					end
				end
			else
				data
			end
		end

		def self.is_date?(field_name, value)
			(field_name.end_with?("_date") || field_name == "date") &&
				value.is_a?(String) &&
				value.to_s != ""
		end

		def self.upload(dir, file, name=file[:filename])
			dir.mkpath

			dir.join(name).open("w") do |f|
				file[:tempfile].rewind # In case of retry, rewind
				until file[:tempfile].eof?
					f.write file[:tempfile].read(4096)
				end
			end
		end
	end
end
