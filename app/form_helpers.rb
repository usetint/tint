module Tint
	module FormHelpers
		def self.process(data, dir)
			case data
			when Array
				data.reject { |v| v.is_a?(String) && v.to_s == "" }.map { |v| process(v, dir) }
			when Hash
				DataProcessor.new(dir).merge!(data).data
			else
				data
			end
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

		class DataProcessor < Hash
			def initialize(dir)
				@dir = dir
				super()
			end

			def data
				send([
					:file, :checkbox, :datetime, :array
				].find { |type| send("is_#{type}?") } || :convert_dates)
			end

		protected

			attr_reader :dir

			def is_file?
				keys.include?(:filename) && keys.include?(:tempfile)
			end

			def is_checkbox?
				keys.include?("___checkbox_unchecked")
			end

			def is_datetime?
				keys.include?("___datetime_date")
			end

			def is_array?
				keys.all? { |k| k =~ /\A\d+\Z/ }
			end

			def file
				uploads = dir.join("uploads").join(Time.now.strftime("%Y"))
				filename = "#{SecureRandom.uuid}-#{self[:filename]}"
				FormHelpers.upload(uploads, self, filename)
				uploads.join(filename).relative_path_from(dir).to_s
			end

			def checkbox
				keys.include?("___checkbox_checked")
			end

			def datetime
				datetime = "#{self["___datetime_date"]} #{self["___datetime_time"]}"
				Time.parse(datetime) if datetime.strip.to_s != ""
			end

			def array
				to_a.sort_by { |x| x.first.to_i }.map(&:last).map { |v| FormHelpers.process(v, dir) }
			end

			def convert_dates
				merge(self) do |k,v|
					v = Date.parse(v) if is_date?(k, v)
					FormHelpers.process(v, dir)
				end.to_h
			end

			def is_date?(field_name, value)
				(field_name.end_with?("_date") || field_name == "date") &&
					value.is_a?(String) &&
					value.to_s != ""
			end
		end
	end
end
