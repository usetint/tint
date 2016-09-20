Sequel.migration do
	change do
		add_column :sites, :domain, String
		add_index :sites, :domain, unique: true
	end
end
