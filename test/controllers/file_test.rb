require_relative "../test_helper"
require_relative "../../app/controllers/file"

describe Tint::Controllers::File do
	include Rack::Test::Methods
	include Tint::Test::StubDB

	def app
		Tint::Controllers::File
	end

	let(:site_options) do
		{
			site_id: 1,
			user_id: 1,
			cache_path: Pathname.new(__FILE__).dirname.join("data/site"),
			fn: "Test Site"
		}
	end

	let(:database) do
		{
			sites: [site_options],
			users: [{ user_id: site_options[:user_id] }]
		}
	end

	let(:site) { Tint::Site.new(site_options) }

	before do
		Tint.db.tables = database
	end

	describe "files root" do
		it "should render without error" do
			get site.route("files"), {}, {
				"rack.session" => { "user" => site_options[:user_id] }
			}
			assert(last_response.ok?)
		end
	end

	describe "getting a text file" do
		let(:file) { site.cache_path.join("index.html") }

		before { file.open("w") { |f| f.write "hello!"  } }
		after { file.delete }

		it "should render without error" do
			get site.route("files/index.html"), {}, {
				"rack.session" => { "user" => site_options[:user_id] }
			}
			assert(last_response.ok?)
		end
	end
end
