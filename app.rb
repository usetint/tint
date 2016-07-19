require "sinatra"
require "sinatra/json"
require "sinatra/reloader"

require "yaml"
require "json"
require "git"
require "sprockets"
require "sass"

if development?
  require "awesome_print"
  require "dotenv"
  require "pry"

  Dotenv.load
end

class Tint < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
  end

  set :environment, Sprockets::Environment.new

  environment.append_path "assets/stylesheets"
  environment.css_compressor = :scss

  project_path = ENV['PROJECT_PATH']

  get "/" do
    erb :index
  end

  get "/assets/*" do
    env["PATH_INFO"].sub!("/assets", "")
    settings.environment.call(env)
  end

  get "/files" do
    files = Dir.glob("#{project_path}/*")
    erb :"files/index", locals: { files: files, root: project_path }
  end

  get "/files/*" do
    path = "#{project_path}/#{params['splat'].join('/')}"
    if File.directory?(path)
      files = Dir.glob("#{path}/*")
      erb :"files/index", locals: { files: files, root: project_path }
    else
      data = YAML.load_file(path)
      erb :"files/yml", locals: { data: data, path: "/files" + path.gsub(project_path, "") }
    end
  end

  post "/files/*" do
    g = Git.open(project_path)
    updated_data = normalize(params['data'])
    new_yml = updated_data.to_yaml
    file_path = "#{project_path}/#{params['splat'].join('/')}"
    original_data = YAML.load_file(file_path)

    if original_data != updated_data
      File.open(file_path, "w") do |file|
        file.write new_yml
      end

      g.add(file_path)
      g.commit("Modified #{params['splat'].join('/')} via tint")
    end

    redirect to("/")
  end

protected

  def transforms
    {
      "on" => true
    }
  end

  def normalize(data)
    if data.is_a? Array
      data.reduce([]) do |new_data, value|
        if value.is_a? Hash
          new_data.push normalize(value)
        elsif value.is_a? Array
          new_data.push value.map { |v| normalize(v) }
        elsif transforms.keys.include? value
          new_data.push transforms[value]
        else
          new_data.push value
        end
        new_data
      end
    elsif data.is_a? Hash
      data.reduce({}) do |new_data, (key, value)|
        if value.is_a? Hash
          new_data[key] = normalize(value)
        elsif value.is_a? Array
          new_data[key] = value.map { |v| normalize(v) }
        elsif transforms.keys.include? value
          new_data[key] = transforms[value]
        else
          new_data[key] = value
        end
        new_data
      end
    else
      data
    end
  end

  helpers do
    def render_yml(value)
      "<ul>#{
      if value.is_a? Hash
        value.map do |key, value|
          "<li>#{render_value(key, value, "data[#{key}]")}</li>"
        end.join
      elsif value.is_a? Array
        value.map { |v| "<li>#{render_value("", v, "data[]")}</li>" }.join
      end
      }</ul>"
    end

    def render_value(key, value, name)
      if value.is_a? Array
        "#{key}<ul>#{value.map { |v| "<li>" + render_value(key, v, "#{name}[]") + "</li>" }.join}</ul>"
      elsif value.is_a? Hash
        value.map do |key, value|
          "#{render_value(key, value, "#{name}[#{key}]")}"
        end.join
      else
        render_input(key, value, name)
      end
    end

    def render_input(key, value, name)
      "<label>#{key}#{
      if [true, false].include? value
        "<input type='checkbox' name='#{name}' #{' checked="checked"' if value} />"
      elsif value.is_a?(String) && value.length > 50
        "<textarea name='#{name}'>#{value}</textarea>"
      else
        "<input type='text' name='#{name}' value='#{value}' />"
      end
      }</label>"
    end
  end
end
