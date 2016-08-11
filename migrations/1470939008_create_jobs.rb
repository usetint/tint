Sequel.migration do
	change do
		create_table :jobs do
			String :job_id, primary_key: true, null: false
			foreign_key :site_id, :sites, null: false
			Time :created_at, null: false
		end
	end
end
