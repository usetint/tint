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

	before do
		Tint.db.tables = database
		file.open("w") { |f| f.write "hello!"  }
	end

	after { file.delete }

	["files", "files/index.html"].each do |route|
		describe "get /#{route}" do
			it "should render without error" do
				get site.route(route), {}, {
					"rack.session" => { "user" => site_options[:user_id] }
				}
				assert(last_response.ok?)
			end
		end
	end
end
