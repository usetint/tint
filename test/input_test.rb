require "minitest/autorun"
require_relative "../app/site"
require_relative "../app/input"

describe Tint::Input do
	describe ".type" do
		subject { Tint::Input.type(key, tvalue, site) }

		let(:site) { OpenStruct.new(config: { "options" => options }) }
		let(:key) { "generic_key" }
		let(:tvalue) { "generic_value" }
		let(:options) { {} }

		describe "when select options includes key" do
			let(:key) { "many_options" }
			let(:options) do
				{ "many_options" => ["option one", "option two"] }
			end

			it "should return MultipleSelect" do
				assert_equal(Tint::Input::MultipleSelect, subject)
			end
		end

		describe "when select options includes pluralized version of key" do
			let(:key) { "pick_one" }
			let(:options) do
				{ "pick_ones" => ["option one", "option two"] }
			end

			it "should return Select" do
				assert_equal(Tint::Input::Select, subject)
			end
		end

		describe "when the value is true" do
			let(:tvalue) { true }

			it "should return Checkbox" do
				assert_equal(Tint::Input::Checkbox, subject)
			end
		end

		describe "when the value is false" do
			let(:tvalue) { false }

			it "should return Checkbox" do
				assert_equal(Tint::Input::Checkbox, subject)
			end
		end

		describe "when the key ends in _path" do
			let(:key) { "a_path" }

			it "should return File" do
				assert_equal(Tint::Input::File, subject)
			end
		end

		describe "when the key ends in _paths" do
			let(:key) { "many_paths" }

			it "should return File" do
				assert_equal(Tint::Input::File, subject)
			end
		end

		describe "when the key ends with _datetime" do
			let(:key) { "what_a_datetime" }

			it "should return DateTime" do
				assert_equal(Tint::Input::DateTime, subject)
			end
		end

		describe "when the key is datetime" do
			let(:key) { "datetime" }

			it "should return DateTime" do
				assert_equal(Tint::Input::DateTime, subject)
			end
		end

		describe "when the value is a Time" do
			let(:tvalue) { Time.new }

			it "should return DateTime" do
				assert_equal(Tint::Input::DateTime, subject)
			end
		end

		describe "when the key ends with _date" do
			let(:key) { "my_awesome_date" }

			it "should return Date" do
				assert_equal(Tint::Input::Date, subject)
			end
		end

		describe "when the key is date" do
			let(:key) { "date" }

			it "should return Date" do
				assert_equal(Tint::Input::Date, subject)
			end
		end

		describe "when the value is a string longer than 50 characters" do
			let(:tvalue) { "A" * 51 }

			it "should return Textarea" do
				assert_equal(Tint::Input::Textarea, subject)
			end
		end

		describe "arrays" do
			describe "when array is scalarish" do
				let(:tvalue) { ["one.ext", "two.ext"] }

				describe "when key ends in _path" do
					let(:key) { "file_path" }

					it "should return File" do
						assert_equal(Tint::Input::File, subject)
					end
				end

				describe "when key ends in _paths" do
					let(:key) { "image_paths" }

					it "should return File" do
						assert_equal(Tint::Input::File, subject)
					end
				end
			end

			describe "when array is not scalarish" do
				let(:tvalue) { [{}, {}] }

				it "should return nil" do
					assert_equal(nil, subject)
				end
			end
		end
	end

	describe ".scalarish?" do
		subject { Tint::Input.scalarish?(tvalue) }

		describe "when value is a string" do
			let(:tvalue) { "totally a scalar" }

			it { assert(subject) }
		end

		describe "when value is a number" do
			let(:tvalue) { 1234 }

			it { assert(subject) }
		end

		describe "when value is a hash" do
			let(:tvalue) { {} }

			it { assert(!subject) }
		end

		describe "when value is an array" do
			describe "when the array is all scalar values" do
				let(:tvalue) { ["one", "two"] }

				it { assert(subject) }
			end

			describe "when the array is all non-scalar values" do
				let(:tvalue) { [{}, {}] }

				it { assert_equal(false, subject) }
			end

			describe "when the array is a mix of scalar and non-scalar values" do
				let(:tvalue) { [{}, "one"] }

				it { assert_equal(false, subject) }
			end
		end
	end
end
