require "minitest/autorun"
require_relative "../app/file"

describe File do
	let(:subject) { Tint::File.new(path) }

	describe "#directory?" do
		describe "when path is directory" do
			let(:path) { "test/data/directory" }

			it "should be true" do
				subject.directory?.must_equal true
			end
		end

		describe "when path is not a directory" do
			let(:path) { "test/data/directory/file" }

			it "should be false" do
				subject.directory?.must_equal false
			end
		end
	end
end
