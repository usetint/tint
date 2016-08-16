require_relative "test_helper"
require_relative "../app/site"

describe Tint::Site do
	let(:subject) { Tint::Site.new(options) }
	let(:default_options) do
		{
			site_id: site_id,
			cache_path: Pathname.new(__FILE__).dirname.join(cache_path),
			fn: "my test site",
			user_id: "3"
		}
	end
	let(:cache_path) { "data" }
	let(:options) { default_options }
	let(:site_id) { 1 }

	describe "#==" do
		describe "when cache_path and type are the same" do
			it "should be considered equal" do
				assert_equal(Tint::Site.new(options), subject)
			end
		end

		describe "when cache_path is not the same" do
			let(:other_site) do
				Tint::Site.new(cache_path: Pathname.new("stuff"))
			end

			it "should not be considered equal" do
				assert_equal(false, other_site == subject)
			end
		end
	end

	describe "#to_h" do
		it "should return the options" do
			assert_equal(options, subject.to_h)
		end

		it "should be a clone of the original options" do
			refute_same(options, subject.to_h)
		end
	end

	describe "#route" do
		describe "without a path" do
			it "should return /:site_id/" do
				assert_equal("/#{site_id}/", subject.route)
			end
		end

		describe "with a path" do
			it "should return /:site_id/:path" do
				path = "path/to/something"
				assert_equal("/#{site_id}/#{path}", subject.route(path))
			end
		end
	end

	describe "#fn" do
		it "should return the value for fn from options" do
			assert_equal(options[:fn], subject.fn)
		end
	end

	describe "#user_id" do
		it "should return the integer value of options[:user_id]" do
			assert_equal(options[:user_id].to_i, subject.user_id)
		end
	end

	describe "#cache_path" do
		describe "when cache_path is passed in" do
			describe "when it does not exist on the file system" do
				let(:cache_path) { "data/nonexistent" }

				before do
					FileUtils.rmtree default_options[:cache_path]
				end

				it "should create the path" do
					refute(default_options[:cache_path].exist?)
					subject.cache_path
					assert(default_options[:cache_path].exist?)
				end

				it "should return the path" do
					assert_equal(default_options[:cache_path], subject.cache_path)
				end

				after do
					FileUtils.rmtree default_options[:cache_path]
				end
			end

			describe "when it does exist on the file system" do
				it "should return the path" do
					assert_equal(default_options[:cache_path], subject.cache_path)
				end
			end
		end

		describe "when no cache_path is passed in" do
			let(:options) do
				options = default_options
				options.delete(:cache_path)
				options
			end

			describe "when it exists in the environment" do
				before do
					ENV["CACHE_PATH"] = default_options[:cache_path].to_s
				end

				after do
					ENV.delete("CACHE_PATH")
				end

				describe "when it does not exist on the file system" do
					let(:cache_path) { "data/nonexistent" }
					let(:expected_path) { default_options[:cache_path].join(site_id.to_s) }

					before do
						FileUtils.rmtree expected_path
					end

					it "should create the path" do
						refute(expected_path.exist?)
						subject.cache_path
						assert(expected_path.exist?)
					end

					it "should return the path with the site_id" do
						assert_equal(
							expected_path,
							subject.cache_path
						)
					end

					after do
						FileUtils.rmtree expected_path
					end
				end

				describe "when it does exist on the file system" do
					it "should return the path with the site_id" do
						assert_equal(
							default_options[:cache_path].join(site_id.to_s),
							subject.cache_path
						)
					end
				end
			end

			describe "when it does not exist in the environment" do
				before { ENV.delete("CACHE_PATH") }

				it "should raise an exception" do
					assert_raises KeyError do
						subject.cache_path
					end
				end
			end
		end
	end

	describe "#valid_config?" do
		it "should return true when unsafe_config does not raise" do
			subject.stub(:unsafe_config, nil) do
				assert(subject.valid_config?)
			end
		end

		it "should return false when unsafe_config raises" do
			subject.stub(:unsafe_config, -> { raise "oops!" }) do
				refute(subject.valid_config?)
			end
		end
	end

	describe "#unsafe_config" do
		describe "when config file does not exist" do
			before { FileUtils.rm(subject.cache_path.join(".tint.yml"), force: true) }

			it "should return empty hash" do
				assert_equal({}, subject.unsafe_config)
			end
		end

		describe "when config file exists" do
			describe "when config file is valid YML" do
				let(:config) { { "my_config_key" => "my config value" } }

				before do
					subject.cache_path.join(".tint.yml").open("w") do |f|
						f.write config.to_yaml
					end
				end

				it "should return the parsed YML" do
					assert_equal(config, subject.unsafe_config)
				end
			end

			describe "when config file is not valid YML" do
				before do
					subject.cache_path.join(".tint.yml").open("w") do |f|
						f.write "\tThis is invalid because tabs"
					end
				end

				it "should raise an error" do
					assert_raises do
						subject.unsafe_config
					end
				end
			end
		end
	end

	describe "#config" do
		describe "when unsafe_config returns a value" do
			let(:config) { { "my key" => "my value" } }

			it "should return that value" do
				subject.stub(:unsafe_config, config) do
					assert_equal(config, subject.config)
				end
			end
		end

		describe "when unsafe_config raises an error" do
			it "should return an empty hash" do
				subject.stub(:unsafe_config, -> { raise "uh oh!" }) do
					assert_equal({}, subject.config)
				end
			end
		end
	end
end
