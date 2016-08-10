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

	describe "#parent" do
		let(:parent) { "directory" }
		let(:path) { "#{parent}/directory" }

		it "should return the parent of this directory" do
			assert_equal(Tint::Directory.new(site, parent), subject.parent)
		end
	end
end
