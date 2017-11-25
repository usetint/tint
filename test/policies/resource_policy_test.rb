require_relative "../test_helper"
require_relative "../../app/policies/resource_policy"

describe Tint::ResourcePolicy do
	subject { Tint::ResourcePolicy.new(user, record) }
	let(:record) { MiniTest::Mock.new }
	let(:resource_user_id) { rand(0..1000) }

	before { record.expect(:user_id, resource_user_id) }

	describe "#index?" do
		describe "when user is falsey" do
			let(:user) { nil }

			it "should return false" do
				refute subject.index?
			end
		end

		describe "when user is truthy" do
			let(:user) { MiniTest::Mock.new }

			before { user.expect(:user_id, user_id) }

			describe "when user.user_id == resource.user_id" do
				let(:user_id) { resource_user_id }

				it "should return true" do
					assert subject.index?
				end
			end

			describe "when user.user_id != resource.user_id" do
				let(:user_id) { 1001 }

				it "should return false" do
					refute subject.index?
				end
			end
		end
	end
end
