module Tint
	module Test
		DB = Struct.new(:tables) do
			def [](key)
				Table.new(tables[key])
			end
		end

		Table = Struct.new(:rows) do
			extend Forwardable
			def_delegators :rows, :first, :map

			def all
				rows
			end

			def join(_table, _columns)
				self
			end

			def [](conditions)
				rows.find do |row|
					(conditions.to_a - row.to_a).empty?
				end
			end

			def where(conditions)
				self.class.new(rows.select do |row|
					(conditions.to_a - row.to_a).empty?
				end)
			end

			def order(property)
				rows.sort_by { |row| row[property] }
			end
		end

		module StubDB
			def run(*args, &block)
				Tint.stub(:db, Tint::Test::DB.new(database)) do
					super
				end
			end
		end
	end
end
