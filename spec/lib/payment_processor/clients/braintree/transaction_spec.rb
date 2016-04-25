require 'rails_helper'

module PaymentProcessor
  module Clients
    module Braintree
      describe Transaction do
        describe '.make_transaction' do

          before do
            allow(MerchantAccountSelector).to receive(:for_currency){ '123' }
            allow(::Braintree::Transaction).to receive(:sale){ transaction }
            allow(ManageBraintreeDonation).to receive(:create){ action }
            allow(Payment).to receive(:write_transaction)
          end

          let(:store) { nil }
          let(:action) { instance_double('Action', member_id: 2) }
          let(:transaction) { instance_double('Braintree::SuccessResult', success?: true) }
          let(:failure) { instance_double('Braintree::ErrorResult', success?: false) }

          let(:required_options) do
            {
              nonce: 'a_nonce',
              amount: 100,
              currency: 'USD',
              user: { email: "bob@example.com", name: 'Bob' },
              page_id: 1
            }
          end

          subject { described_class }

          [:nonce, :amount, :currency, :user, :page_id].each do |keyword|
            it "requires a #{keyword}" do
              expect{
                required_options.delete(keyword)
                subject.make_transaction(**required_options)
              }.to raise_error(ArgumentError, "missing keyword: #{keyword}")
            end
          end

          it 'passes basic arguments' do
            expected_arguments = {
              amount: 100,
              payment_method_nonce:       'a_nonce',
              merchant_account_id:        '123',
              options: {
               submit_for_settlement:     true,
               store_in_vault_on_success: true
              },
              customer: {
                first_name:               'Bob',
                last_name:                '',
                email:                    'bob@example.com'
              },
              billing: {
                first_name: 'Bob',
                last_name: ''
              }
            }

            expect(::Braintree::Transaction).to receive(:sale).with(expected_arguments){ transaction }

            subject.make_transaction(required_options)
          end

          it 'passes customer_id' do
            customer = create :payment_braintree_customer, email: required_options[:user][:email]
            expect(::Braintree::Transaction).to receive(:sale).
              with( hash_including(customer_id: customer.customer_id) )

            subject.make_transaction(required_options)
          end

          describe 'result' do
            ## TODO: Need to confirm we're happy with this changed behaviour.
            #
            it 'does NOT return the Braintree result object when successful' do
              builder = subject.make_transaction(required_options)
              expect{builder.result}.to raise_error(NoMethodError)
            end

            it 'returns the Braintree result object when unsuccessful' do
              allow(::Braintree::Transaction).to receive(:sale){ failure }
              builder = subject.make_transaction(required_options)
              expect(builder.success?).to be(false)
            end
          end

          describe 'action' do
            it 'returns the Action object when successful' do
              builder = subject.make_transaction(required_options)
              expect(builder.action).to eq action
            end

            it 'returns nil when unsuccessful' do
              allow(::Braintree::Transaction).to receive(:sale){ failure }
              builder = subject.make_transaction(required_options)
              expect(builder.action).to eq nil
            end
          end

          describe 'customer field' do
            describe 'includes name if' do
              let(:name_expectation) do
                a_hash_including(
                  customer: a_hash_including(
                    first_name: 'Frank',
                    last_name: 'Weeki-waki'
                  )
                )
              end

              it 'includes name if given as first_name, last_name' do
                expect(::Braintree::Transaction).to receive(:sale).with(name_expectation){ transaction }
                subject.make_transaction(required_options.merge(user: {
                  first_name: 'Frank',
                  last_name: 'Weeki-waki'
                }))
              end

              it 'includes name if given as full_name' do
                expect(::Braintree::Transaction).to receive(:sale).with(name_expectation){ transaction }
                subject.make_transaction(required_options.merge(user: {
                  full_name: 'Frank Weeki-waki'
                }))
              end

              it 'includes name if given as name' do
                expect(::Braintree::Transaction).to receive(:sale).with(name_expectation){ transaction }
                subject.make_transaction(required_options.merge(user: {
                  name: 'Frank Weeki-waki'
                }))
              end
            end

            it 'passes user email if available' do
              expected = a_hash_including(customer: a_hash_including( email: 'user@test.com') )
              expect(::Braintree::Transaction).to receive(:sale).with(expected){ transaction }

              subject.make_transaction(required_options.merge(user: { email: 'user@test.com' }))
            end

            it 'passes an empty string if no known email' do
              expected = a_hash_including(customer: a_hash_including( email: ''))
              expect(::Braintree::Transaction).to receive(:sale).with(expected){ transaction }

              subject.make_transaction(required_options.merge(user: {} ))
            end
          end

          describe 'billing field' do

            describe 'postal code' do
              let(:expected) { a_hash_including( billing: a_hash_including( postal_code: '01060' ) ) }

              it 'can be filled by zip' do
                expect(::Braintree::Transaction).to receive(:sale).with(expected){ transaction }
                subject.make_transaction(required_options.merge(user: { zip: '01060'} ))
              end

              it 'can be filled by zip_code' do
                expect(::Braintree::Transaction).to receive(:sale).with(expected){ transaction }
                subject.make_transaction(required_options.merge(user: { zip_code: '01060'} ))
              end

              it 'can be filled by postal' do
                expect(::Braintree::Transaction).to receive(:sale).with(expected){ transaction }
                subject.make_transaction(required_options.merge(user: { postal: '01060'} ))
              end

              it 'can be filled by postal_code' do
                expect(::Braintree::Transaction).to receive(:sale).with(expected){ transaction }
                subject.make_transaction(required_options.merge(user: { postal_code: '01060'} ))
              end

              it 'prioritizes postal_code' do
                expect(::Braintree::Transaction).to receive(:sale).with(expected){ transaction }
                subject.make_transaction(required_options.merge(user: {
                  zip: '00000',
                  zip_code: '00000',
                  postal: '00000',
                  postal_code: '01060'
                }))
              end
            end

            describe 'street address' do
              let(:expected) { a_hash_including( billing: a_hash_including( street_address: '71 Pleasant St' ) ) }

              it 'can be filled by address' do
                expect(::Braintree::Transaction).to receive(:sale).with(expected){ transaction }
                subject.make_transaction(required_options.merge(user: { address: '71 Pleasant St'} ))
              end

              it 'can be filled by address1' do
                expect(::Braintree::Transaction).to receive(:sale).with(expected){ transaction }
                subject.make_transaction(required_options.merge(user: { address1: '71 Pleasant St'} ))
              end

              it 'can be filled by street_address' do
                expect(::Braintree::Transaction).to receive(:sale).with(expected){ transaction }
                subject.make_transaction(required_options.merge(user: { street_address: '71 Pleasant St'} ))
              end

              it 'prioritizes street_address' do
                expect(::Braintree::Transaction).to receive(:sale).with(expected){ transaction }
                subject.make_transaction(required_options.merge(user: {
                  address: 'derp town',
                  address1: 'derp town',
                  street_address: '71 Pleasant St'
                }))
              end
            end

            describe 'extended address' do
              let(:expected) { a_hash_including( billing: a_hash_including( extended_address: 'First floor' ) ) }

              it 'can be filled by apartment' do
                expect(::Braintree::Transaction).to receive(:sale).with(expected){ transaction }
                subject.make_transaction(required_options.merge(user: { apartment: 'First floor'} ))
              end

              it 'can be filled by address2' do
                expect(::Braintree::Transaction).to receive(:sale).with(expected){ transaction }
                subject.make_transaction(required_options.merge(user: { address2: 'First floor'} ))
              end

              it 'can be filled by extended_address' do
                expect(::Braintree::Transaction).to receive(:sale).with(expected){ transaction }
                subject.make_transaction(required_options.merge(user: { extended_address: 'First floor'} ))
              end

              it 'prioritizes extended_address' do
                expect(::Braintree::Transaction).to receive(:sale).with(expected){ transaction }
                subject.make_transaction(required_options.merge(user: {
                  apartment: 'derp town',
                  address2: 'derp town',
                  extended_address: 'First floor'
                }))
              end
            end

            describe 'country' do
              let(:expected) { a_hash_including( billing: a_hash_including( country_code_alpha2: 'US' ) ) }

              it 'can be filled by country' do
                expect(::Braintree::Transaction).to receive(:sale).with(expected){ transaction }
                subject.make_transaction(required_options.merge(user: { country: 'US'} ))
              end

              it 'can be filled by country_code' do
                expect(::Braintree::Transaction).to receive(:sale).with(expected){ transaction }
                subject.make_transaction(required_options.merge(user: { country_code: 'US'} ))
              end

              it 'can be filled by country_code_alpha2' do
                expect(::Braintree::Transaction).to receive(:sale).with(expected){ transaction }
                subject.make_transaction(required_options.merge(user: { country_code_alpha2: 'US'} ))
              end

              it 'prioritizes country_code_alpha2' do
                expect(::Braintree::Transaction).to receive(:sale).with(expected){ transaction }
                subject.make_transaction(required_options.merge(user: {
                  country: 'NI',
                  country_code: 'NI',
                  country_code_alpha2: 'US'
                }))
              end
            end

            describe 'region' do
              let(:expected) { a_hash_including( billing: a_hash_including( region: 'Massachusetts' ) ) }

              it 'can be filled by province' do
                expect(::Braintree::Transaction).to receive(:sale).with(expected){ transaction }
                subject.make_transaction(required_options.merge(user: { province: 'Massachusetts'} ))
              end

              it 'can be filled by state' do
                expect(::Braintree::Transaction).to receive(:sale).with(expected){ transaction }
                subject.make_transaction(required_options.merge(user: { state: 'Massachusetts'} ))
              end

              it 'can be filled by region' do
                expect(::Braintree::Transaction).to receive(:sale).with(expected){ transaction }
                subject.make_transaction(required_options.merge(user: { region: 'Massachusetts'} ))
              end

              it 'prioritizes region' do
                expect(::Braintree::Transaction).to receive(:sale).with(expected){ transaction }
                subject.make_transaction(required_options.merge(user: {
                  province: 'Lapland',
                  state: 'Lapland',
                  region: 'Massachusetts'
                }))
              end
            end

            describe 'region' do
              let(:expected) { a_hash_including( billing: a_hash_including( locality: 'Northampton' ) ) }

              it 'can be filled by city' do
                expect(::Braintree::Transaction).to receive(:sale).with(expected){ transaction }
                subject.make_transaction(required_options.merge(user: { city: 'Northampton'} ))
              end

              it 'can be filled by locality' do
                expect(::Braintree::Transaction).to receive(:sale).with(expected){ transaction }
                subject.make_transaction(required_options.merge(user: { locality: 'Northampton'} ))
              end

              it 'prioritizes locality' do
                expect(::Braintree::Transaction).to receive(:sale).with(expected){ transaction }
                subject.make_transaction(required_options.merge(user: {
                  city: 'Managua',
                  locality: 'Northampton'
                }))
              end
            end

            describe 'company' do
              let(:expected) { a_hash_including( billing: a_hash_including( company: "Mimmo's Pizza" ) ) }

              it 'can be filled by company' do
                expect(::Braintree::Transaction).to receive(:sale).with(expected){ transaction }
                subject.make_transaction(required_options.merge(user: { company: "Mimmo's Pizza" } ))
              end
            end
          end
        end
      end
    end
  end
end

