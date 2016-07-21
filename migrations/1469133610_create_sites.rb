Sequel.migration do
	change do
		create_table :sites do
			primary_key :site_id
			foreign_key :user_id, :users, null: false
			String :remote, null: false
			String :fn, null: false
		end
	end
end
