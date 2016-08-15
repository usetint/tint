require_relative "test_helper"
require_relative "../app/site"
require_relative "../app/file"

describe Tint::File do
	let(:site) { test_site }
	let(:path) { "directory/file" }
	let(:subject) { site.file(path) }

	describe "#name" do
		describe "when no name is passed" do
			it "should use the name from the path" do
				assert_equal(path.split("/").last, subject.name)
			end
		end

		describe "when a name is explicitly passed" do
			let(:subject) { Tint::File.new(site, path, tname) }
			let(:tname) { ".." }

			it "should use the name that was given" do
				assert_equal(tname, subject.name)
			end
		end
	end
end
