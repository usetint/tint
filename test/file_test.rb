require_relative "test_helper"
require_relative "../app/site"
require_relative "../app/file"

describe Tint::File do
	let(:site) { test_site }
	let(:path) { "directory/file" }
	let(:subject) { Tint::File.new(site, path) }

	mime_methods = [:text?, :image?]
	mime_types = ["text/plain; charset=us-ascii", "image/jpeg; charset=binary"]

	mime_methods.zip(mime_types) do |method, type|
		describe "##{method}" do
			describe "when mime is #{type}" do
				it "should return true" do
					subject.stub(:mime, type) do
						assert(subject.public_send(method))
					end
				end
			end

			other_types = mime_types.reject { |t| t == type }
			other_types.each do |other_type|
				describe "when mime is #{other_type}" do
					it "should return false" do
						subject.stub(:mime, other_type) do
							assert_equal(false, subject.public_send(method))
						end
					end
				end
			end
		end
	end

	extensions = {
		markdown?: [:md, :markdown],
		yml?: [:yml, :yaml]
	}

	extensions.each do |method, exts|
		describe "##{method}" do
			let(:path) { "directory/file.#{extension}" }

			exts.each do |ext|
				describe "when extension is #{ext}" do
					before { site.resource(path).mkpath }

					let(:extension) { ext }

					it "should be true" do
						assert(subject.public_send(method))
					end
				end
			end
		end
	end

	describe "file with content" do
		let(:path) { "file_with_content.md" }

		describe "#content?" do
			it { assert(subject.content?) }
		end

		describe "#frontmatter?" do
			it { assert_equal(false, subject.frontmatter?) }
		end
	end

	describe "file with content and frontmatter" do
		let(:path) { "content_and_frontmatter.md" }

		describe "#content?" do
			it { assert(subject.content?) }
		end

		describe "#frontmatter?" do
			it { assert(subject.frontmatter?) }
		end

		describe "#frontmatter" do
			it "should return the parsed frontmatter" do
				assert_equal({
					"layout"=>"page",
					"title"=>"About",
					"permalink"=>"/about/"
				}, subject.frontmatter)
			end
		end
	end

	describe "file with no content" do
		let(:path) { "no_content.yml" }

		describe "#content?" do
			it { assert_equal(false, subject.content?) }
		end

		describe "#frontmatter?" do
			it { assert(subject.frontmatter?) }
		end

		describe "#frontmatter" do
			it "should return the parsed frontmatter" do
				assert_equal({
					"hello" => "my name is"
				}, subject.frontmatter)
			end
		end
	end

	describe "image file" do
		let(:path) { "20150501-IMG_9497.jpg" }

		describe "#content?" do
			it { refute(subject.content?) }
		end

		describe "#frontmatter?" do
			it { refute(subject.frontmatter?) }
		end

		describe "#frontmatter" do
			it "should return nil" do
				assert_nil(subject.frontmatter)
			end
		end

		describe "when the site config has frontmatter rules" do
			before { set_frontmatter_rules(site) }

			describe "#frontmatter?" do
				it "should return nil" do
					refute(subject.frontmatter?)
				end
			end
		end
	end

	def set_frontmatter_rules(site)
		site.cache_path.join(".tint.yml").open("w") do |f|
			f.puts(YAML::dump("filename_frontmatter" => {
				"*" => [
					{"key" => "date", "strptime" => "%Y-%m-%d"},
					{"match" => "-"},
					{"key" => "title", "match" => "[^\\.]+", "format" => "slugify" }
				]
			}))
		end
	end

	describe "yml file with array as root element" do
		describe "a file without frontmatter parsed from filename" do
			let(:path) { "array_root.yml" }

			it "should not raise an error" do
				subject.frontmatter
			end

			it "should return the contents of the file" do
				assert_equal ["one", "two", "three", "four"], subject.frontmatter
			end
		end

		describe "a file with frontmatter parsed from filename" do
			before { set_frontmatter_rules(site) }

			let(:path) { "filename_frontmatter/2016-01-01-array-root.yml" }

			it "should raise an exception" do
				err = assert_raises Tint::File::IncompatibleFrontmatter do
					subject.frontmatter
				end

				assert_equal "Files with frontmatter in their filename cannot have a Array as their root element.", err.message
			end
		end
	end

	describe "file with frontmatter in filename" do
		before { set_frontmatter_rules(site) }

		after do
			site.cache_path.join(".tint.yml").unlink
		end

		describe "and in file" do
			let(:path) { "filename_frontmatter/2016-01-01-with-frontmatter.md" }

			describe "#frontmatter?" do
				it { assert(subject.frontmatter?) }
			end

			describe "#frontmatter" do
				it "should return the parsed frontmatter and from filename" do
					assert_equal({
						"other" => "stuff",
						"title" => "with-frontmatter",
						"date" => Date.new(2016, 01, 01)
					}, subject.frontmatter)
				end
			end

			describe "#relative_path_with_frontmatter" do
				it { assert_equal(subject.relative_path_with_frontmatter, subject.relative_path) }
			end
		end

		describe "and overlapping in file" do
			let(:path) { "filename_frontmatter/2010-01-01-with-overlapping-frontmatter.md" }

			describe "#frontmatter?" do
				it { assert(subject.frontmatter?) }
			end

			describe "#frontmatter" do
				it "should return the parsed frontmatter overriding from filename" do
					assert_equal({
						"title" => "Other Title",
						"date" => Date.new(1980, 10, 10)
					}, subject.frontmatter)
				end
			end

			describe "#relative_path_with_frontmatter" do
				it { assert_equal(subject.relative_path_with_frontmatter, Pathname.new("filename_frontmatter/1980-10-10-other-title.md")) }
			end
		end

		describe "binary file" do
			let(:path) { "filename_frontmatter/2015-01-01-binary.bin" }

			describe "#frontmatter?" do
				it { assert(subject.frontmatter?) }
			end

			describe "#frontmatter" do
				it "should return from filename" do
					assert_equal({
						"title" => "binary",
						"date" => Date.new(2015, 01, 01)
					}, subject.frontmatter)
				end
			end

			describe "#relative_path_with_frontmatter" do
				it { assert_equal(subject.relative_path_with_frontmatter, subject.relative_path) }
			end
		end

		describe "nonexistant file" do
			let(:path) { "filename_frontmatter/2015-01-01-this-file-is-not-here.md" }

			describe "#frontmatter" do
				it "should return from filename" do
					assert_equal({
						"title" => "this-file-is-not-here",
						"date" => Date.new(2015, 01, 01)
					}, subject.frontmatter)
				end
			end

			describe "#relative_path_with_frontmatter" do
				it { assert_equal(subject.relative_path_with_frontmatter, subject.relative_path) }
			end
		end
	end
end
