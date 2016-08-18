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
	let(:file) { site.cache_path.join("index.html") }
	let(:session) { { "rack.session" => { "user" => site_options[:user_id] } } }

	before do
		Tint.db.tables = database
		file.open("w") { |f| f.write "hello!"  }
	end

	after { file.delete }

	["files", "files/index.html"].each do |route|
		describe "get /#{route}" do
			it "should render without error" do
				response = get site.route(route), {}, session.merge("HTTP_ACCEPT" => "text/html")
				assert(response.ok?)
			end
		end
	end

	describe "get /files json" do
		it "should return content type json" do
			response = get site.route("files.json"), {}, session.merge("HTTP_ACCEPT" => "application/json")
			assert_equal("application/json", response.headers["Content-Type"])
		end
	end
end
