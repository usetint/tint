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
      data = YAML.safe_load(open(path))
      erb :"files/yml", locals: { data: data, path: "/files" + path.gsub(project_path, "") }
    end
  end

  post "/files/*" do
    file_path = "#{project_path}/#{params['splat'].join('/')}"
    original_data = YAML.safe_load(open(file_path))
    updated_data = normalize(params['data'])

    if original_data != updated_data
      Tempfile.open('tint-save') do |tmp|
        tmp.puts updated_data.to_yaml
        stream_after_frontmatter(file_path, &tmp.method(:puts))
        FileUtils.mv(tmp.path, file_path, force: true)
      end

      g = Git.open(project_path)
      g.add(file_path)
      g.commit("Modified #{params['splat'].join('/')} via tint")
    end

    redirect to("/")
  end

protected

  def stream_after_frontmatter(path)
    doc_start = 0
    File.foreach(path) do |line|
      line.chomp!
      if line == '---'
        doc_start += 1
        next if doc_start < 2
      end

      yield line if doc_start >= 2
    end
  end

  def normalize(data)
    case data
    when Array
      data.map &method(:normalize)
    when Hash
      if data.keys.include?('___checkbox_unchecked')
        data.keys.include?('___checkbox_checked')
      elsif data.keys.all? { |k| k =~ /\A\d+\Z/ }
        data.to_a.sort_by(&:first).map(&:last).map &method(:normalize)
      else
        data.merge(data) { |k,v| normalize(v) }
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
        value.each_with_index.map { |v, i| render_value(nil, v, "data[#{i}]") }.join
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
          value.each_with_index.map { |v, i| "<li>#{render_value(nil, v, "#{name}[#{i}]")}</li>" }.join
        }</ol></fieldset>"
      else
        render_input(key, value, name)
      end
    end

    def render_input(key, value, name)
      input = if [true, false].include? value
        "
          <input type='hidden' name='#{name}[___checkbox_unchecked]' value='' />
          <input type='checkbox' name='#{name}[___checkbox_checked]' #{' checked="checked"' if value} />
        "
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
