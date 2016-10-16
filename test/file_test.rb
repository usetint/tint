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

	describe "file with frontmatter in filename" do
		before do
			site.cache_path.join(".tint.yml").open("w") do |f|
				f.puts(YAML::dump("filename_frontmatter" => {
					"filename_frontmatter/*" => [
						{"key" => "date", "strptime" => "%Y-%m-%d"},
						{"match" => "-"},
						{"key" => "title", "match" => "[^\\.]+", "format" => "slugify" }
					]
				}))
			end
		end

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
end
