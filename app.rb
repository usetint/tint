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
      case value
      when Hash
        value.map { |k, v| render_value(k, v, "data[#{k}]") }.join
      when Array
        value.map { |v| render_value(nil, v, "data[]") }.join
      else
        raise TypeError, 'YAML root must be a Hash or Array'
      end
    end

    def render_value(key, value, name)
      case value
      when Hash
        "<fieldset>#{"<legend>#{key}</legend>" if key}#{
        value.map do |key, value|
          "#{render_value(key, value, "#{name}[#{key}]")}"
        end.join
        }</fieldset>"
      when Array
        "<fieldset><legend>#{key}</legend><ol>#{
          value.map { |v| "<li>#{render_value(nil, v, "#{name}[]")}</li>" }.join
        }</ol></fieldset>"
      else
        render_input(key, value, name)
      end
    end

    def render_input(key, value, name)
      input = if [true, false].include? value
        "<input type='checkbox' name='#{name}' #{' checked="checked"' if value} />"
      elsif value.is_a?(String) && value.length > 50
        "<textarea name='#{name}'>#{value}</textarea>"
      else
        "<input type='text' name='#{name}' value='#{value}' />"
      end

      if key
        "<label>#{key} #{input}</label>"
      else
        input
      end
    end
  end
end
