class ChangeColumnNames < ActiveRecord::Migration
  def change
    rename_column :campaigns, :campaign_name, :name
    rename_column :tags, :tag_name, :name

    drop_table :plugin_settings
  end
end