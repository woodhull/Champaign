ActiveAdmin.register LiquidPartial do
  actions :all, except: [:new, :edit, :destroy]

  index do
    selectable_column
    id_column
    column :title
    actions
  end

  sidebar 'Previous Versions', only: :show do
    attributes_table_for liquid_partial do
      row :versions do
        render '/versions/versions_link', model: liquid_partial, model_name: 'liquid_partial'
      end
    end
  end
end
