Sequel.migration do
	change do
		alter_table :jobs do
			drop_foreign_key [:site_id]
			add_foreign_key [:site_id], :sites, on_delete: :cascade
		end
	end
end
