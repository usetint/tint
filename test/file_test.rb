require_relative "test_helper"
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

	describe "#user_id" do
		it "should call user_id on site" do
			assert_method_called_on_member(subject, :site, :user_id)
		end
	end

	describe "#parent" do
		it "should return a new Tint::Directory" do
			assert_equal(Tint::Directory.new(site, Pathname.new(path).dirname), subject.parent)
		end
	end

	describe "#path" do
		describe "when inside the project directory" do
			let(:path) { "directory/file" }

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
			let(:other) { Tint::File.new(site, path) }

			it "should be considered equal" do
				assert_equal(other, subject)
			end
		end
	end
end
