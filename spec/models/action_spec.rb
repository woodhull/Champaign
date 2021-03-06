require 'rails_helper'

describe Action do
  let(:page) { create :page }

  describe 'on create' do
    subject{ create(:action, page_id: page.id) }

    describe 'counter_cache on page' do
      it 'increases the action_count after creation' do
        expect { subject}.to change{ page.reload.action_count }.from(0).to(1)
      end

      it 'does not stamp updated_at' do
        expect { subject }.not_to change{ page.reload.updated_at }
      end

      it 'does not change cache_key' do
        expect { subject }.not_to change{ page.reload.cache_key }
      end
    end
  end
end

