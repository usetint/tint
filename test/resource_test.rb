require_relative "test_helper"
require_relative "../app/site"
require_relative "../app/resource"

describe Tint::Resource do
	let(:site) { test_site }
	let(:path) { "directory/file" }
	let(:subject) { Tint::Resource.new(site, path) }

	describe "#users" do
		it "should call users on site" do
			assert_method_called_on_member(subject, :site, :users)
		end
	end

	describe "#parent" do
		it "should return a new Tint::Directory with the parent path" do
			assert_equal(Tint::Directory.new(site, "directory"), subject.parent)
		end
	end

	describe "#route" do
		it "should call route on site with 'files/:relative_path'" do
			assert_method_called_on_member(subject, :site, :route, "files/#{path}")
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
		describe "when it is a Resource and the paths are the same" do
			let(:other) { Tint::Resource.new(site, path) }

			it "should be considered equal" do
				assert_equal(other, subject)
			end
		end
	end

	describe "#name" do
		it "should return the path basename" do
			assert_equal(path.split("/").last, subject.fn)
		end
	end

	describe "#fn" do
		describe "when no name is passed" do
			it "should use the name from the path" do
				assert_equal(path.split("/").last, subject.fn)
			end
		end

		describe "when a name is explicitly passed" do
			let(:subject) { Tint::Resource.new(site, path, tname) }
			let(:tname) { ".." }

			it "should use the name that was given" do
				assert_equal(tname, subject.fn)
			end
		end

		describe "when path is same as site path" do
			let(:subject) { Tint::Resource.new(site, site.cache_path) }

			it "should return the string 'files'" do
				assert_equal("files", subject.fn)
			end
		end
	end

	path_methods = [:exist?, :directory?, :size, :open, :rename, :write, :mkpath, :join, :children, :file?]

	describe "#respond_to?" do
		describe "our own methods" do
			Tint::Resource.new(:site, "file").public_methods.each do |method|
				it "should respond to #{method}" do
					assert(subject.respond_to?(method))
				end
			end
		end

		describe "path methods we care about" do
			path_methods.each do |method|
				it "should respond to #{method} from path" do
					assert(subject.respond_to?(method))
				end
			end
		end
	end

	path_methods.each do |method|
		it "should call #{method} on path" do
			assert_method_called_on_member(subject, :path, method)
		end
	end
end
