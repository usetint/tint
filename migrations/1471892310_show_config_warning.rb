Sequel.migration do
	change do
		alter_table :sites do
			add_column :show_config_warning, TrueClass, null: false, default: true
		end
	end
end
