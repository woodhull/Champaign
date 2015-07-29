require 'aws-sdk'
require 'fake_sqs/test_integration'

# AWS Config for local fake SQS
Aws.config.update(
    region: "us-east-1",
    credentials: Aws::Credentials.new("fake", "fake"),
)

db = ENV["SQS_DATABASE"] || ":memory:"
puts "\n\e[34mRunning specs with database \e[33m#{db}\e[0m"

$fake_sqs = FakeSQS::TestIntegration.new(
    database: db,
    sqs_endpoint: "localhost",
    sqs_port: 4568,
)

RSpec.configure do |config|
  # RSpec config for fake SQS
  config.before(:each, :sqs) { $fake_sqs.start }
  config.before(:each, :sqs) { $fake_sqs.reset }
  config.after(:suite) { $fake_sqs.stop }
end