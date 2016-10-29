require_relative "test_helper"
require_relative "../app/helpers"
require "minitest/mock"

describe Tint::Helpers::Rendering do
	describe "#render_value" do
		let(:subject) do
			Class.new {
				include Tint::Helpers::Rendering

				define_method(:site) { test_site }
			}.new
		end

		describe "when place has defined options" do
			before do
				test_site.cache_path.join(".tint.yml").open("w") do |f|
					f.puts(YAML::dump("options" => {
						"places" => ["Toronto", "Tokyo"]
					}))
				end
			end

			after do
				test_site.cache_path.join(".tint.yml").unlink
			end

			it "should not raise exception " do
				subject.render_value("place", [nil], "place")
			end
		end
	end
end
