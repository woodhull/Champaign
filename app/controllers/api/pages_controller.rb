require 'rack'

class Api::PagesController < ApplicationController
  before_action :get_page
  layout false

  def show
    respond_to do |format|
      format.json
    end
  end

  def update
    updater = PageUpdater.new(@page)
    if updater.update(all_params)
      render json: { refresh: updater.refresh? }, status: :ok
    else
      render json: { errors: shallow_errors(updater.errors) }, status: 422
    end
  end

  private

  def all_params
    # this is pretty janky but it's the best I can do moving quickly
    # and serializing a bunch of rails forms into one thing
    # the real key is Rack::Utils.parse_nested_query(params.to_query)
    # which turns {'page[title]' => 'hi'} into {page: {title: 'hi'}}
    # it also doesn't use strong params.
    unwrapped = {}
    Rack::Utils.parse_nested_query(params.to_query).each_pair do |key, nested|
      next unless nested.is_a? Hash
      nested.each_pair do |subkey, subnested|
        if subnested.is_a? Hash
          unwrapped[key] = subnested
        end
      end
    end
    unwrapped.with_indifferent_access
  end

  def shallow_errors(errors)
    Rack::Utils.parse_query(errors.to_query)
  end

  def get_page
    @page = Page.find(params[:id])
  end

end

