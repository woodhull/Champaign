require 'rails_helper'

describe ActionBuilder do
  let(:page) { create :page }
  let(:member) { create :member }
  let(:found_action) { Action.where(member: member, page: page).first }

  # Create a class which includes the ActionBuilder.
  class MockActionBuilder
    include ActionBuilder

    def initialize(params)
      @params = params
    end
  end

  subject { MockActionBuilder.new(page_id: page.id, email: member.email).build_action }

  context 'with existing member' do
    it 'increments cache counter with new_member as false' do
      expect(Analytics::Page).to receive(:increment).with(page.id, new_member: false)
      subject
    end
  end

  context 'with new member' do
    it 'increments cache counter with new_member as true' do
      expect(Analytics::Page).to receive(:increment).with(page.id, new_member: true)
      MockActionBuilder.new(page_id: page.id, email: 'new@example.com').build_action
    end
  end

  it 'enqueues action' do
    expect(ChampaignQueue).to receive(:push)
    subject
  end

  it 'correctly finds the expected page' do
    mab = MockActionBuilder.new(page_id: page.id)
    expect(mab.page).to eq(page)
  end

  it 'correctly finds created users' do
    mab = MockActionBuilder.new(email: member.email)
    expect(mab.member).to eq(member)
  end

  it 'correctly changes the attributes of provided users' do
    person = member
    not_real = 'Not a real country.'
    expect(person.country).to_not eq(not_real)
    mab = MockActionBuilder.new(email: person.email, country: not_real)
    expect(mab.member.country).to eq(not_real)
  end

  it 'correctly builds and returns actions' do
    mab = MockActionBuilder.new(page_id: page.id, email: member.email)
    expect(mab.build_action).to eq(found_action)
  end

  it 'correctly builds and finds previous actions' do
    mab = MockActionBuilder.new(page_id: page.id, email: member.email)
    mab.build_action
    expect(mab.previous_action).to eq(found_action)
  end

  describe 'permitted_keys' do

    let(:mab) { MockActionBuilder.new(page_id: page.id, email: member.email) }

    it 'returns symbols' do
      expect(mab.permitted_keys.map(&:class).uniq).to eq [Symbol]
    end

    it 'does not include the id' do
      expect(mab.permitted_keys).not_to include(:id)
    end

    it 'includes all the other keys of member' do
      expect(mab.permitted_keys).to include(:email, :country, :first_name, :last_name, :city, :postal, :title, :address1, :address2, :actionkit_user_id)
    end
  end

  describe 'filtered_params' do

    let(:params) { {email: "silly@billy.com", country: "US", first_name: "Silly", last_name: "Billy", city: "Northampton", postal: "01060", address1: "10 Coates St.", address2: ""} }

    describe 'passes all' do

      it 'keys as symbols' do
        mab = MockActionBuilder.new(params)
        expect(mab.filtered_params).to eq params
      end

      it 'keys as strings' do
        mab = MockActionBuilder.new(params.stringify_keys)
        expect(mab.filtered_params).to eq params
      end

      it 'keys with indifferent access' do
        mab = MockActionBuilder.new(params.with_indifferent_access)
        expect(mab.filtered_params).to eq params
      end

      it 'keys as action parameters' do
        mab = MockActionBuilder.new(ActionController::Parameters.new(params))
        expect(mab.filtered_params).to eq params
      end
    end

    describe 'filters irrelevant' do

      let(:porky_params) { params.merge(page_id: page.id, form_id: '3', blerg: false, akid: '1234.514.lQVxcW') }

      it 'keys as symbols' do
        mab = MockActionBuilder.new(porky_params)
        expect(mab.filtered_params).to eq params
      end

      it 'keys as strings' do
        mab = MockActionBuilder.new(porky_params.stringify_keys)
        expect(mab.filtered_params).to eq params
      end

      it 'keys with indifferent access' do
        mab = MockActionBuilder.new(porky_params.with_indifferent_access)
        expect(mab.filtered_params).to eq params
      end

      it 'keys as action parameters' do
        mab = MockActionBuilder.new(ActionController::Parameters.new(porky_params))
        expect(mab.filtered_params).to eq params
      end

      it 'but passes them through to form_data' do
        mab = MockActionBuilder.new(porky_params)
        expect{ mab.build_action }.to change{ Action.count }.by 1
        expect(Action.last.form_data).to match a_hash_including(params.stringify_keys)
      end
    end
  end
end

