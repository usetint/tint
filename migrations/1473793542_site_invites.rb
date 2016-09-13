Sequel.migration do
	up do
		if (database_type = self.database_type) == :postgres
			extension :pg_enum
		end

		create_table :site_invites do
			String :invite_code, null: false
			Time :expires_at, null: false
			foreign_key :site_id, :sites, null: false

			if database_type == :postgres
				site_role :role, null: false
			else
				String :role, null: false
			end
		end

		alter_table :site_invites do
			add_primary_key [:invite_code]
			add_index [:expires_at]
		end
	end

	down do
		drop_table :site_invites
	end
end
