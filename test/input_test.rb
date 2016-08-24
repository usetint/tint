require_relative "test_helper"
require_relative "../app/input"

describe Tint::Input do
	describe ".type" do
		subject { Tint::Input.type(key, tvalue, site) }

		let(:site) { OpenStruct.new(config: { "options" => options }) }
		let(:key) { "generic_key" }
		let(:tvalue) { "generic_value" }
		let(:options) { {} }

		describe "config defined select options" do
			let(:options) do
				{ "many_options" => ["option one", "option two"] }
			end

			describe "when options includes key" do
				let(:key) { "many_options" }

				it "should return MultipleSelect" do
					assert_equal(Tint::Input::MultipleSelect, subject)
				end
			end

			describe "when options includes pluralized version of key" do
				let(:key) { "many_option" }

				it "should return Select" do
					assert_equal(Tint::Input::Select, subject)
				end
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

		describe "when the value is a Date" do
			let(:tvalue) { Date.new }

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

		describe "when the key is description" do
			let(:key) { "description" }

			it "should return Textarea" do
				assert_equal(Tint::Input::Textarea, subject)
			end
		end

		describe "when key ends in _text" do
			let(:key) { "something_text" }

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
		subject { Tint::Input.scalarish?(val) }

		describe "when value is a string" do
			let(:val) { "totally a scalar" }

			it { assert(subject) }
		end

		describe "when value is a number" do
			let(:val) { 1234 }

			it { assert(subject) }
		end

		describe "when value is a hash" do
			let(:val) { {} }

			it { assert(!subject) }
		end

		describe "when value is an array" do
			describe "when the array is all scalar values" do
				let(:val) { ["one", "two"] }

				it { assert(subject) }
			end

			describe "when the array is all non-scalar values" do
				let(:val) { [{}, {}] }

				it { assert_equal(false, subject) }
			end

			describe "when the array is a mix of scalar and non-scalar values" do
				let(:val) { [{}, "one"] }

				it { assert_equal(false, subject) }
			end
		end
	end

	describe Tint::Input::Select do
		let(:subject) { Tint::Input::Select.new(nil, nil, val, nil) }

		describe "#options" do
			[
				[
					[1, 2, 3],
					[[1, 1, true], [2, 2, false], [3, 3, false]],
					"single value"
				],
				[
					{ 1 => "one", 2 => "two", 3 => "three" },
					[[1, "one", true], [2, "two", false], [3, "three", false]],
					"value and display"
				]
			].each do |options, expected, desc|
				describe "when options are a #{desc}" do
					let(:options) { options }

					["1", 1].each do |value|
						describe "when value is a #{value.class}" do
							let(:val) { value }

							it "should return the options with the value selected" do
								Tint::Input.stub(:select_options, options) do
									assert_equal(expected, subject.options)
								end
							end
						end
					end
				end
			end
		end
	end

	describe Tint::Input::MultipleSelect do
		let(:subject) { Tint::Input::MultipleSelect.new(nil, nil, val, nil) }

		describe "#value" do
			describe "when value is nil" do
				let(:val) { nil }

				it "should return an empty array" do
					assert_equal([], subject.value)
				end
			end

			describe "when value is an array" do
				let(:val) { [:one, :two, :three] }

				it "should return it" do
					assert_equal(val, subject.value)
				end
			end
		end
	end
end
