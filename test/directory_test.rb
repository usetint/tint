require_relative "test_helper"
require_relative "../app/site"
require_relative "../app/directory"

describe Tint::Directory do
	let(:site) do
		Tint::Site.new(
			site_id: 1,
			user_id: 1,
			cache_path: Pathname.new(__FILE__).dirname.join("data"),
			fn: "Test Site"
		)
	end
	let(:path) { "directory" }
	let(:subject) { Tint::Directory.new(site, path) }

	describe "#path" do
		describe "when inside the project directory" do
			let(:path) { "directory" }

			it "should return the path" do
				assert_equal(site.cache_path.join(path).realdirpath, subject.path)
			end
		end

		describe "when outside the project directory" do
			let(:path) { "../../stuff.md" }

			it "should raise an exception" do
				assert_raises { subject.path }
			end
		end
	end

	describe "#==" do
		describe "when the paths are the same" do
			let(:other) { Tint::Directory.new(site, path) }

			it "should be considered equal" do
				assert_equal(other, subject)
			end
		end
	end
end
