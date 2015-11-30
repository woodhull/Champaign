class Plugins::Action < ActiveRecord::Base
  belongs_to :page
  belongs_to :form

  validates :cta, presence: true, allow_blank: false

  after_create :create_form

  DEFAULTS = { cta: 'Sign the Petition' }

  def liquid_data
    attributes.merge(form_id: form.try(:id), fields: form_fields)
  end

  def form_fields
    form ? form.form_elements.map(&:attributes) : []
  end

  def name
    self.class.name.demodulize
  end

  private

  def create_form
    update(form: Form.create(master: false, name: "action:#{id}"))
  end
end
