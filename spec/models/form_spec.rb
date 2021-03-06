require 'rails_helper'

describe Form do
  describe '.masters' do
    before do
      create(:form, master: false)
      create(:form, master: true)
    end

    it 'returns only masters' do
      expect(Form.masters.map(&:master?)).to eq([true])
    end
  end

  describe '#master' do
    it 'can be a master' do
      form = create(:form, master: true)
      expect(form.master?).to be true
    end
  end

  describe "formable" do
    it 'is polymorphically associated' do
      petition = create(:plugins_fundraiser)

      expect(petition.form).to be_a Form
      expect(Form.last.formable).to eq(petition)
    end
  end

  describe 'validations' do
    context 'formable' do
      it 'must be unique' do
        create(:form, formable_id: 1, formable_type: 'Plugins::Petition')

        expect{
          create(:form, formable_id: 1, formable_type: 'Plugins::Petition')
        }.to raise_error("Validation failed: Formable has already been taken")

        expect{
          create(:form, formable_id: 1, formable_type: 'Plugins::Fundraiser')
        }.not_to raise_error
      end
    end

    context 'name' do
      it "must be present" do
        expect(Form.new).to_not be_valid
      end

      context 'for non-master' do
        it 'uniqueness is not necessary' do
          create(:form, master: true, name: 'Foo')

          new_form = Form.create(master:false, name: 'Foo')
          expect(new_form.errors[:name]).to be_empty
        end
      end

      context 'for master' do
        it 'must be unique' do
          create(:form, master: true, name: 'Foo')
          new_form = Form.create(master:true, name: 'Foo')
          expect(new_form.errors[:name]).to eq(['must be unique'])
        end
      end
    end
  end
end

