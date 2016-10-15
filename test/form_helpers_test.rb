require_relative "test_helper"
require_relative "../app/form_helpers"
require "minitest/mock"

describe Tint::FormHelpers do
	describe "#process" do
		let(:subject) { Tint::FormHelpers }
		let(:dir) { Pathname.new(__FILE__).dirname.join("data") }

		describe "when data is an array" do
			let(:data) { ["", ["one", "", "three"]] }

			it "should remove the empty strings" do
				results = subject.process(data, dir)
				assert_equal([["one", "three"]], results)
			end
		end

		describe "when data is a hash" do
			describe "when keys include file and tempfile" do
				let(:data) { { filename: "hello.txt", tempfile: dir.join("directory/file").open } }

				it "should return the relative path from dir" do
					subject.stub(:upload, nil) do
						assert(subject.process(data, dir).start_with?("uploads/#{Time.now.strftime("%Y")}"))
					end
				end
			end

			describe "when keys include ___checkbox_unchecked" do
				describe "when keys also include ___checkbox_checked" do
					let(:data) { { "___checkbox_unchecked" => true, "___checkbox_checked" => true } }

					it "should return true" do
						assert_equal(true, subject.process(data, dir))
					end
				end

				describe "when keys do not include __checkbox_checked" do
					let(:data) { { "___checkbox_unchecked" => true } }

					it "should return false" do
						assert_equal(false, subject.process(data, dir))
					end
				end
			end

			describe "when we are sending in a datetime" do
				let(:data) { { "___datetime_date" => date, "___datetime_time" => vtime } }
				let(:date) { "2016-08-02" }
				let(:vtime) { "22:55:58" }

				it "should return a time object with the parsed date and time" do
					assert_equal(Time.parse("#{date} #{vtime}"), subject.process(data, dir))
				end

				describe "when both are blank" do
					let(:date) { "" }
					let(:vtime) { "" }

					it "should return nil" do
						assert_equal(nil, subject.process(data, dir))
					end
				end

				describe "when datetime is invalid" do
					let(:date) { "boop" }
					let(:vtime) { "boop" }

					it "should throw catchable exception" do
						assert_raises(Tint::FormHelpers::Invalid) do
							subject.process(data, dir)
						end
					end
				end
			end

			describe "when we are sending in a pretend array" do
				let(:data) { { "1" => "two", "0" => "one", "2" => "three" } }

				it "should return the data as an array in the order of the numbered keys" do
					assert_equal(["one", "two", "three"], subject.process(data, dir))
				end
			end

			describe "date parsing" do
				let(:date) { "2016-08-02" }
				let(:parsed) { Date.parse(date) }

				[["date", "is"], ["awesome_date", "ends in"]].each do |key, descriptor|
					describe "when a key #{descriptor} date" do
						let(:data) { { key => date } }

						it "should return the parsed Date at that key" do
							assert_equal({ key => parsed }, subject.process(data, dir))
						end

						it "should return a Hash" do
							assert_equal(Hash, subject.process(data, dir).class)
						end
					end
				end

				describe "when date is invalid" do
					let(:data) { { "date" => "boop" } }

					it "should throw catchable exception" do
						assert_raises(Tint::FormHelpers::Invalid) do
							subject.process(data, dir)
						end
					end
				end
			end
		end

		["blah blah", 123, Time.now, Date.today, :things].each do |object|
			describe "when data is a #{object.class}" do
				it "should return the object" do
					assert_equal(object, subject.process(object, dir))
				end
			end
		end
	end
end
