class AddVisibleToForms < ActiveRecord::Migration
  def change
    add_column :forms, :visible, :boolean, default: false
  end
end
