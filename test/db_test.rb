require_relative "test_helper"
require_relative "db"

describe Tint::Test do
	let(:data) do
		{
			sites: [1,2,3,4].map { |i| { site_id: i } },
			users: [6,7,8,9].map { |i| { user_id: i } }
		}
	end

	describe Tint::Test::DB do
		let(:subject) { Tint::Test::DB.new(data) }

		describe "#[]" do
			it "should return a new table with the rows at key name" do
				assert_equal(
					Tint::Test::Table.new(data[:sites]),
					subject[:sites]
				)
			end
		end
	end

	describe Tint::Test::Table do
		let(:subject) { Tint::Test::Table }

		describe "#==" do
			describe "when rows are equal" do
				let(:table1) { subject.new(data[:sites]) }
				let(:table2) { subject.new(data[:sites]) }

				it "should be equal" do
					assert_equal(table1, table2)
				end
			end

			describe "when rows are not equal" do
				let(:table1) { subject.new(data[:sites]) }
				let(:table2) { subject.new(data[:users]) }

				it "should not be equal" do
					refute_equal(table1, table2)
				end
			end
		end

		describe "#all" do
			let(:subject) { Tint::Test::Table.new(rows) }
			let(:rows) { data[:sites] }

			it "should return the rows" do
				assert_equal(rows, subject.all)
			end
		end

		describe "#[]" do
			let(:subject) { Tint::Test::Table.new(row) }
			let(:row) { data[:sites] }

			describe "when there is no matching row" do
				it "should return nil" do
					assert_equal(nil, subject[site_id: 1000])
				end
			end

			describe "when there is a matching row" do
				it "should return the first matching row" do
					assert_equal(row[0], subject[site_id: row[0][:site_id]])
				end
			end
		end

		describe "#where" do
			let(:subject) { Tint::Test::Table.new(row) }
			let(:row) { data[:sites] }

			describe "when there are no matching rows" do
				it "should return an empty array" do
					assert_equal(Tint::Test::Table.new([]), subject.where(site_id: 1000))
				end
			end

			describe "when there are matching rows" do
				it "should return an array of them" do
					assert_equal(Tint::Test::Table.new([row[0]]), subject.where(site_id: row[0][:site_id]))
				end
			end
		end

		describe "#order" do
			let(:subject) { Tint::Test::Table.new(shuffled) }
			let(:table) do
				[
					{ site_id: 1, name: "AAAAAAA" },
					{ site_id: 2, name: "BBBBBBB" },
					{ site_id: 2, name: "CCCCCCC" },
					{ site_id: 2, name: "ZZZZZZZ" }
				]
			end
			let(:shuffled) { table.shuffle }

			describe "when key exists" do
				it "should order the results by that key" do
					assert_equal(table, subject.order(:name))
				end
			end

			describe "when key does not exist" do
				it "should do nothing something" do
					assert_equal(shuffled, subject.order(:notaproperty))
				end
			end

			describe "when chained with where" do
				let(:expected) { table.reject { |row| row[:site_id] == 1 } }

				it "should return a filtered and ordered list" do
					assert_equal(expected, subject.where(site_id: 2).order(:name))
				end
			end
		end
	end
end
