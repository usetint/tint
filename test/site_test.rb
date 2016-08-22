require_relative "test_helper"
require_relative "../app/site"

describe Tint::Site do
	let(:subject) { Tint::Site.new(options) }
	let(:default_options) do
		{
			site_id: site_id,
			cache_path: Pathname.new(__FILE__).dirname.join(cache_path),
			deploy_path: Pathname.new(__FILE__).dirname.join(deploy_path),
			fn: "my test site",
			user_id: "3"
		}
	end
	let(:cache_path) { "data" }
	let(:deploy_path) { "deploy" }
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

			it "should url encode the path" do
				path = "path/to/new folder"
				expected_path = path.split("/").map { |s| ERB::Util.url_encode(s) }.join("/")
				assert_equal("/#{site_id}/#{expected_path}", subject.route(path))
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

	[:cache_path, :deploy_path].each do |path_method|
		describe "##{path_method}" do
			describe "when #{path_method} is passed in" do
				describe "when it does not exist on the file system" do
					let(path_method) { "data/#{path_method}_nonexistent" }

					before do
						FileUtils.rmtree default_options[path_method]
					end

					it "should create the path" do
						refute(default_options[path_method].exist?)
						subject.public_send(path_method)
						assert(default_options[path_method].exist?)
					end

					it "should return the path" do
						assert_equal(default_options[path_method], subject.public_send(path_method))
					end

					after do
						FileUtils.rmtree default_options[path_method]
					end
				end

				describe "when it does exist on the file system" do
					it "should return the path" do
						assert_equal(default_options[path_method], subject.public_send(path_method))
					end
				end
			end

			describe "when no cache_path is passed in" do
				let(:options) do
					options = default_options
					options.delete(path_method)
					options
				end

				describe "when it exists in the environment" do
					before do
						ENV[path_method.to_s.upcase] = default_options[path_method].to_s
					end

					after do
						ENV.delete(path_method.to_s.upcase)
					end

					describe "when it does not exist on the file system" do
						let(:cache_path) { "data/#{path_method}_nonexistent" }
						let(:expected_path) { default_options[path_method].join(site_id.to_s) }

						before do
							FileUtils.rmtree expected_path
						end

						it "should create the path" do
							refute(expected_path.exist?)
							subject.public_send(path_method)
							assert(expected_path.exist?)
						end

						it "should return the path with the site_id" do
							assert_equal(expected_path, subject.public_send(path_method))
						end

						after do
							FileUtils.rmtree expected_path
						end
					end

					describe "when it does exist on the file system" do
						it "should return the path with the site_id" do
							assert_equal(
								default_options[path_method].join(site_id.to_s),
								subject.public_send(path_method)
							)
						end
					end
				end

				describe "when it does not exist in the environment" do
					before { ENV.delete(path_method.to_s.upcase) }

					it "should raise an exception" do
						assert_raises KeyError do
							subject.public_send(path_method)
						end
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
			after do
				subject.cache_path.join(".tint.yml").delete
			end

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

	describe "#git" do
		it "should call Git.open with the cache path" do
			mock = MiniTest::Mock.new
			mock.expect :call, true, [subject.cache_path]

			Git.stub(:open, mock) do
				subject.git
			end

			mock.verify
		end
	end

	describe "#status" do
		describe "when status is passed via options" do
			let(:options) { default_options.merge(status: status) }
			let(:status) { :my_status }

			it "should return it" do
				assert_equal(status, subject.status)
			end
		end

		describe "when status is not passed via options" do
			describe "when Tint.db is nil" do
				before { ENV["SITE_PATH"] = "totallyapath" }

				it "should return nil" do
					assert_equal(nil, subject.status)
				end

				after { ENV.delete("SITE_PATH") }
			end

			describe "when Tint.db is not nil" do
				include Tint::Test::StubDB

				let(:database) do
					{
						jobs: [{ job_id: 1, site_id: options[:site_id] }]
					}
				end

				before do
					class FakeBuildJob
						def self.get(*_)
							new
						end

						def status
							:job_status
						end
					end

					Tint::BuildJob = FakeBuildJob
				end

				it "should get the job out of the db and return its status" do
					assert_equal(:build_job_status, subject.status)
				end
			end
		end
	end

	describe "#remote" do
		let(:options) { default_options.merge(remote: :remote_control) }

		it "should return the remote from options" do
			assert_equal(options[:remote], subject.remote)
		end
	end

	describe "#clear_cache!" do
		let(:cache_path) { "data/clearable" }

		it "should remove the cache_path directory" do
			subject.cache_path
			assert(options[:cache_path].exist?)
			subject.clear_cache!
			refute(options[:cache_path].exist?)
		end
	end

	[
		[:git?, ".git"],
		[:cloned?, ".git/tint-cloned"]
	].each do |method, path|
		describe method do
			describe "when #{path} exists" do
				before { subject.cache_path.join(path).mkpath }

				it "should return true" do
					assert(subject.public_send(method))
				end

				after { subject.cache_path.join(path).rmtree }
			end

			describe "when #{path} does not exist" do
				before { FileUtils.rm_r(subject.cache_path.join(path), force: true) }

				it "should return false" do
					refute(subject.public_send(method))
				end
			end
		end
	end

	describe "#resource" do
		[
			["directory", Tint::Directory],
			["directory/file", Tint::File],
			["directory/iamnotreal", Tint::Directory]
		].each do |path, target_class|
			describe "when path is #{path}" do
				let(:path) { path }

				it "should return a #{target_class} with self and the path" do
					assert_equal(Tint::Directory.new(subject, path), subject.resource(path))
				end
			end
		end
	end

	describe "#makefile?" do
		describe "when it has a Makefile" do
			before { FileUtils.touch(subject.cache_path.join("Makefile").to_s) }

			after { FileUtils.rm(subject.cache_path.join("Makefile").to_s, force: true) }

			it "should be true" do
				assert(subject.makefile?)
			end
		end

		describe "when it does not have a Makefile" do
			before { FileUtils.rm(subject.cache_path.join("Makefile").to_s, force: true) }

			it "should be false" do
				refute(subject.makefile?)
			end
		end
	end
end
