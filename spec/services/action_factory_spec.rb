require 'rails_helper'

describe ActionFactory do
  let(:page) { create(:page) }

  let(:params) do
    {
      email: 'foo@example.com',
      page_id: page.id,
      member: {
        first_name: 'Camilo',
        last_name:  'Cienfuegos'
      },
      form_data: {
        foo: 'bar'
      }
    }
  end

  subject { ActionFactory.new( params )}

  describe 'creating a new action / member' do
    before do
      subject.run
      @action = Action.first
    end

    it 'with associated page' do
      expect(@action.page).to eq(page)
    end

    it 'with member' do
      expect(@action.member.email).to eq('foo@example.com')
    end

    it 'subscribes member' do
      expect(@action.subscribed_member).to eq(true)
    end

    it 'with form data' do
      expect(@action.form_data).to eq({'foo' => 'bar'})
    end
  end

  describe 'a new action with existing member' do
    before do
      create(:member, email: 'foo@example.com')
    end

    it 'does not create new member' do
      expect{
        subject.run
      }.to_not change{ Member.count }.from(1)
    end

    it 'creates action' do
      expect{
        subject.run
      }.to change{ Action.count }.from(0).to(1)
    end

    it 'does not subscribe member' do
      subject.run
      expect(Action.first.subscribed_member).to be(false)
    end
  end

  describe 'attempting to create an existing action' do
    before do
      create(:action,
        member: create(:member, email: 'foo@example.com'),
        page: page
      )
    end

    it 'does nothing' do
      expect{
        subject.run
      }.to_not change{ Action.count }.from(1)

      expect(Member.count).to eq(1)
    end
  end
end
