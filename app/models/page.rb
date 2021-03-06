class Page < ActiveRecord::Base
  extend FriendlyId
  has_paper_trail

  enum follow_up_plan: [:with_liquid, :with_page] # todo - :with_link

  belongs_to :language
  belongs_to :campaign # Note that some pages do not necessarily belong to campaigns
  belongs_to :liquid_layout
  belongs_to :follow_up_page, class_name: 'Page'
  belongs_to :follow_up_liquid_layout, class_name: 'LiquidLayout'
  belongs_to :primary_image, class_name: 'Image'

  has_many :tags, through: :pages_tags
  has_many :actions
  has_many :pages_tags, dependent: :destroy
  has_many :images,     dependent: :destroy
  has_many :links,      dependent: :destroy

  validates :title, presence: true, uniqueness: true
  validates :liquid_layout, presence: true
  validate  :primary_image_is_owned

  after_save :switch_plugins

  friendly_id :title, use: [:finders, :slugged]

  def liquid_data
    attributes.merge(link_list: links.map(&:attributes))
  end

  def plugins
    Plugins.registered.map do |plugin_class|
      plugin_class.where(page_id: id).to_a
    end.flatten.sort_by(&:created_at)
  end

  def plugin_names
    plugins.map { |plugin| plugin.model_name.name.split('::')[1].downcase }
  end

  def tag_names
    tags.map { |tag| tag.name.downcase }
  end

  def shares
    [Share::Facebook, Share::Twitter, Share::Email].inject([]) do |variations, share_class|
      variations += share_class.where(page_id: id)
    end
  end

  def image_to_display
    primary_image || images.first
  end

  def meta_tags
    tag_names << plugin_names
  end

  private

  def switch_plugins
    if changed.include?("liquid_layout_id")
      PagePluginSwitcher.new(self).switch(liquid_layout)
    end
  end

  def primary_image_is_owned
    unless primary_image_id.blank? || images.map(&:id).include?(primary_image_id)
      errors.add(:primary_image_id, "is not one of the page's images")
    end
  end
end

