Sequel.migration do
	change do
		create_table :users do
			primary_key :user_id
			String :email
			String :fn
		end

		create_table :identities do
			String :provider, null: false
			String :uid, null: false
			String :omniauth, text: true, null: false
			foreign_key :user_id, :users, null: false
		end

		alter_table :identities do
			add_primary_key [:provider, :uid]
		end
	end
end
