require 'render_anywhere'

class Page < ActiveRecord::Base
  include RenderAnywhere
  has_paper_trail

  belongs_to :language
  belongs_to :campaign # Note that some pages do not necessarily belong to campaigns
  belongs_to :liquid_layout

  has_many :pages_tags, dependent: :destroy
  has_many :tags, through: :pages_tags
  has_many :actions
  has_many :images
  has_many :links

  validates :title, :slug, presence: true, uniqueness: true
  validates :liquid_layout, presence: true

  before_validation :create_slug

  # have we thought about using friendly id? probably better
  def create_slug
    self.slug = title.parameterize if slug.nil? and not title.nil?
  end

  # Compiles the HTML for this Page so that it can be used by external display apps.
  def compile_html
    PageRenderer.new(self).render_and_save
  end

  def liquid_data
    attributes.merge(link_list: links.map(&:attributes))
  end

  def plugins
    Plugins.registered.map do |plugin_class|
      plugin_class.where(page_id: id).to_a
    end.flatten
  end
end
