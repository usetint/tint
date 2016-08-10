require_relative "test_helper"
require_relative "../app/site"

describe Tint::Site do
	let(:subject) { Tint::Site.new(options) }
	let(:options) do
		{
			cache_path: Pathname.new(__FILE__).dirname.join("data")
		}
	end

	describe "#==" do
		describe "when cache_path is the same" do
			it "should be considered equal" do
				assert_equal(Tint::Site.new(options), subject)
			end
		end

		describe "when cache_path is not the same" do
			let(:other_site) do
				Tint::Site.new(cache_path: Pathname.new("stuff"))
			end

			it "should not be considered equal" do
				assert_equal(false, other_site == subject)
			end
		end
	end
end
