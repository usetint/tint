require_relative "../app/travis_job"

describe Tint::TravisJob do
	describe ".queue_dir" do
		let(:subject) { Tint::TravisJob }

		describe "when TRAVIS_WORKER_BASE_DIR is set in ENV" do
			let(:travis_path) { test_data_path.join("travis") }

			before { ENV["TRAVIS_WORKER_BASE_DIR"] = travis_path.to_s }

			describe "when the path exists" do
				before { travis_path.mkpath }
				after { FileUtils.rm_r travis_path, force: true }

				it "should return the path" do
					assert_equal(travis_path, subject.queue_dir)
				end
			end

			describe "when the path does not exist" do
				before { FileUtils.rm_r travis_path, force: true }

				it "should create the path" do
					refute(travis_path.exist?)
					subject.queue_dir
					assert(travis_path.exist?)
				end

				it "should return the path" do
					assert_equal(travis_path, subject.queue_dir)
				end
			end
		end

		describe "when there is no TRAVIS_WORKER_BASE_DIR" do
			before { ENV.delete("TRAVIS_WORKER_BASE_DIR") }

			it "should be nil" do
				assert_equal(nil, subject.queue_dir)
			end
		end
	end
end
