require_relative "test_helper"
require_relative "../app/site"
require_relative "../app/file"

describe Tint::File do
	let(:site) do
		Tint::Site.new(
			site_id: 1,
			user_id: 1,
			cache_path: Pathname.new(__FILE__).dirname.join("data"),
			fn: "Test Site"
		)
	end
	let(:path) { "directory/file" }
	let(:subject) { site.file(path) }

	describe "#exist?" do
		it "should call exist? on path" do
			assert_method_called_on_member(subject, :path, :exist?)
		end
	end

	describe "#directory?" do
		it "should call directory? on path" do
			assert_method_called_on_member(subject, :path,  :directory?)
		end
	end

	describe "#size" do
		it "should call size on path" do
			assert_method_called_on_member(subject, :path, :size)
		end
	end

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
