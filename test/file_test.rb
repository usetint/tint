require "minitest/autorun"
require_relative "../app/site"
require_relative "../app/file"

describe File do
	let(:site) do
		Tint::Site.new(
			site_id: 1,
			user_id: 1,
			cache_path: Pathname.new(__FILE__).dirname.join("data"),
			fn: "Test Site"
		)
	end
	let(:subject) { site.file(path) }

	describe "#directory?" do
		describe "when path is directory" do
			let(:path) { "directory" }

			it "should be true" do
				subject.directory?.must_equal true
			end
		end

		describe "when path is not a directory" do
			let(:path) { "directory/file" }

			it "should be false" do
				subject.directory?.must_equal false
			end
		end
	end
end
