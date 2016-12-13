source "https://rubygems.org"

gem "sinatra"
gem "sinatra-contrib"

gem "activesupport", "< 5.0.0" # For pundit
gem "git", github: "usetint/ruby-git"
gem "git-annex", github: "usetint/ruby-git-annex"
gem "github_api"
gem "gitlab"
gem "httparty"
gem "omniauth"
gem "omniauth-bitbucket", github: "sishen/omniauth-bitbucket"
gem "omniauth-github"
gem "omniauth-gitlab"
gem "omniauth-indieauth"
gem "omniauth-oauth2", "~> 1.3.1"
gem "ruby-filemagic"
gem "ruby_dig", github: "invoca/ruby_dig"
gem "sass"
gem "sequel"
gem "sinatra-pundit"
gem "skim"
gem "slim"
gem "slugify"
gem "sprockets"
gem "tilt", "1.4"

group :production do
	gem "pg"
	gem "sentry-raven"
end

group :development do
	gem "awesome_print"
	gem "dotenv"
	gem "pry"
	gem "pry-byebug"
	gem "scss_lint"
	gem "sqlite3"
end

group :test do
	gem "codeclimate-test-reporter", require: nil
	gem "rake"
end
