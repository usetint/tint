require_relative "../test_helper"
require_relative "../../app/git_providers/git_providers"

describe Tint::GitProviders do
  let(:subject) { Tint::GitProviders }

  describe ".extract_from_remote" do
    let(:username) { "yayauser" }
    let(:repo) { "yayarepo" }
    let(:remote) { "#{prefix}git@github.com:#{username}/#{repo}.git" }

    describe "when remote does not have ssh:// in front of it" do
      let(:prefix) { "" }

      it "should return the username and repo" do
        assert_equal([username, repo], subject.extract_from_remote(remote))
      end
    end

    describe "when remote does not have ssh:// in front of it" do
      let(:prefix) { "ssh://" }

      it "should return the username and repo" do
        assert_equal([username, repo], subject.extract_from_remote(remote))
      end
    end
  end
end
