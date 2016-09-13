Sequel.migration do
	up do
		if (database_type = self.database_type) == :postgres
			extension :pg_enum
			create_enum(:site_role, [:owner, :client])
		end

		create_table :site_users do
			foreign_key :site_id, :sites, null: false
			foreign_key :user_id, :users, null: false

			if database_type == :postgres
				site_role :role, null: false, default: "client"
			else
				String :role, null: false, default: "client"
			end
		end

		alter_table :site_users do
			add_primary_key [:site_id, :user_id]
		end

		self[:sites].all.each do |site|
			self[:site_users].insert(
				site_id: site[:site_id],
				user_id: site[:user_id],
				role: "owner"
			)
		end

		drop_column :sites, :user_id
	end

	down do
		alter_table :sites do
			add_foreign_key :user_id, :users
		end

		self[:site_users].where(role: "owner").each do |site_user|
			self[:sites].where(site_id: site_user[:site_id]).update(user_id: site_user[:user_id])
		end

		drop_table :site_users

		if database_type == :postgres
			extension :pg_enum
			drop_enum :site_role
		end
	end
end
