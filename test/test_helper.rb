require "codeclimate-test-reporter"
CodeClimate::TestReporter.start

require "minitest/autorun"
require "rack/test"
require "pry"
require "securerandom"

require_relative "db"

ENV["SESSION_SECRET"] = SecureRandom.uuid

def assert_method_called_on_member(subject, member, method, args=[])
	mock = MiniTest::Mock.new
	mock.expect method, true, Array(args)

	subject.stub member, mock do
		subject.public_send(method)
		assert(mock.verify)
	end
end

def test_site
	Tint::Site.new(
		site_id: 1,
		user_id: 1,
		cache_path: Pathname.new(__FILE__).dirname.join("data"),
		fn: "Test Site"
	)
end

def test_data_path
	Pathname.new(__FILE__).dirname.join("data")
end
