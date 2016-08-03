Sequel.migration do
	change do
		add_column :sites, :status, String
	end
end
