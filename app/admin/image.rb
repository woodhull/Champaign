ActiveAdmin.register Image do
  actions :all, except: [:new, :edit, :destroy]

  sidebar 'Previous Versions', only: :show do
    attributes_table_for image do
      row :versions do
        render '/versions/versions_link', model: image, model_name: 'image'
      end
    end
  end
end
