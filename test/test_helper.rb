require "codeclimate-test-reporter"
CodeClimate::TestReporter.start

require "minitest/autorun"

def assert_method_called_on_member(subject, member, method, args=[])
	mock = MiniTest::Mock.new
	mock.expect method, true, Array(args)

	subject.stub member, mock do
		subject.public_send(method)
		assert(mock.verify)
	end
end
