require_relative "test_helper"
require_relative "../app/site"
require_relative "../app/directory"

describe Tint::Directory do
	let(:site) { test_site }
	let(:path) { "directory" }
	let(:subject) { Tint::Directory.new(site, path) }

	describe "#parent" do
		let(:parent) { "directory" }
		let(:path) { "#{parent}/directory" }

		it "should return the parent of this directory" do
			assert_equal(Tint::Directory.new(site, parent), subject.parent)
		end
	end

	describe "#files" do
		let(:sub) { Tint::Directory.new(site, dir) }
		let(:dir) do
			dir = subject.path.join("dirtest")
			dir.mkpath
			dir
		end

		before do
			files = [:one, :two, :three, :four].map { |name| dir.join(name.to_s) }
			FileUtils.touch files
		end

		after do
			dir.rmtree
		end

		it "should list and sort files and directories" do
			assert_equal(
				["..", "four", "one", "three", "two"],
				sub.files.map(&:name)
			)
		end
	end
end
