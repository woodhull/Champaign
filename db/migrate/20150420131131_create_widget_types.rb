class CreateWidgetTypes < ActiveRecord::Migration
  def change
    create_table :widget_types do |t|
      t.string :widget_name, null: false, unique: true
      t.jsonb :specifications, null: false
      t.string :action_table_name, unique: true 
      t.timestamps
      t.boolean :active, null: false
    end
  end
end
