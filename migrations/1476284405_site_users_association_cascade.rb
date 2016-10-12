Sequel.migration do
	change do
		alter_table :site_users do
			# When site is removed, remove association to user
			drop_foreign_key [:site_id]
			add_foreign_key [:site_id], :sites, on_delete: :cascade

			# When user is removed, remove association to site
			drop_foreign_key [:user_id]
			add_foreign_key [:user_id], :users, on_delete: :cascade
		end
	end
end
