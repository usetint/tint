require "sinatra"
require "sinatra/json"
require "sinatra/reloader"
require "sinatra/streaming"

require "filemagic"
require "git"
require "json"
require "sass"
require "sprockets"
require "yaml"

if development?
  require "awesome_print"
  require "dotenv"
  require "pry"

  Dotenv.load
end

class Tint < Sinatra::Base
  helpers Sinatra::Streaming

  configure :development do
    register Sinatra::Reloader
  end

  set :environment, Sprockets::Environment.new
  set :method_override, true

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
      is_text = FileMagic.open(:mime) do |magic|
        magic.file(path).split('/').first == 'text'
      end

      if is_text
        has_content, has_frontmatter = detect_content_or_frontmatter(path)
        if path.split(/\./).last.downcase == 'yml' || !has_content
          data = YAML.safe_load(open(path))
          erb :"files/yml", locals: { data: data, path: "/files" + path.gsub(project_path, "") }
        else
          wysiwyg = ['md', 'markdown'].include?(path.split(/\./).last.downcase)
          frontmatter = has_frontmatter && YAML.safe_load(open(path))
          stream do |out|
            html = erb :"files/text", locals: { frontmatter: frontmatter, wysiwyg: wysiwyg, path: "/files" + path.gsub(project_path, "") }
            top, bottom = html.split('<textarea name="content">', 2)
            out.puts top
            out.puts '<textarea name="content">'
            stream_content(path, &out.method(:puts))
            out.puts bottom
          end
        end
      else
        'Editing binary files is not supported'
      end
    end
  end

  put "/files/*" do
    file_path = "#{project_path}/#{params['splat'].join('/')}"
    updated_data = normalize(params['data'])

    Tempfile.open('tint-save') do |tmp|
      if updated_data
        tmp.puts updated_data.to_yaml
        tmp.puts '---'
      end
      if params.has_key?('content')
        tmp.puts(params['content'].gsub(/\r\n?/, "\n"))
      else
        stream_content(file_path, &tmp.method(:puts))
      end
      FileUtils.mv(tmp.path, file_path, force: true)
    end

    g = Git.open(project_path)
    g.add(file_path)

    g.status.each do |f|
      if f.path == params['splat'].join('/') && f.type
        g.commit("Modified #{params['splat'].join('/')} via tint")
      end
    end

    redirect to("/")
  end

protected

  def detect_content_or_frontmatter(path)
    has_frontmatter = false
    File.foreach(path).with_index do |line, idx|
      line.chomp!
      if line == '---' && idx == 0
        has_frontmatter = true
        next
      end

      if has_frontmatter && line == '---'
        return [true, has_frontmatter]
      end
    end

    [!has_frontmatter, has_frontmatter]
  end

  def stream_content(path)
    has_frontmatter = false
    doc_start = 0
    File.foreach(path).with_index do |line, idx|
      line.chomp!

      if doc_start < 2
        has_frontmatter = true if line == '---' && idx == 0
        doc_start += 1 if line == '---'
        next if has_frontmatter
      end

      yield line
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
