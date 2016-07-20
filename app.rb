require "sinatra"
require "sinatra/json"
require "sinatra/reloader"
require "sinatra/streaming"

require "filemagic"
require "git"
require "json"
require "pathname"
require "sass"
require "sprockets"
require "yaml"

if development?
  require "awesome_print"
  require "dotenv"
  require "pry"

  Dotenv.load
end

module Tint
  PROJECT_PATH = ENV["PROJECT_PATH"]

  class App < Sinatra::Base
    helpers Sinatra::Streaming

    configure :development do
      register Sinatra::Reloader
    end

    set :environment, Sprockets::Environment.new
    set :method_override, true

    environment.append_path "assets/stylesheets"
    environment.css_compressor = :scss

    def project_path
      Pathname.new(PROJECT_PATH).realpath.to_s
    end

    get "/" do
      erb :index
    end

    get "/assets/*" do
      env["PATH_INFO"].sub!("/assets", "")
      settings.environment.call(env)
    end

    get "/files" do
      render_directory project_path
    end

    get "/files/*" do
      path = "#{project_path}/#{params['splat'].join('/')}"
      file = Tint::File.new(path)

      if file.directory?
        render_directory path
      elsif file.text?
        if file.yml? || !file.content?
          erb :"layouts/files" do
            erb :"files/yml", locals: {
              data: file.frontmatter,
              path: file.route
            }
          end
        else
          frontmatter = file.frontmatter? && file.frontmatter
          stream do |out|
            html = erb :"layouts/files" do
              erb :"files/text", locals: {
                frontmatter: frontmatter,
                wysiwyg: file.markdown?,
                path: file.route
              }
            end
            top, bottom = html.split('<textarea name="content">', 2)
            out.puts top
            out.puts '<textarea name="content">'
            file.stream_content(&out.method(:puts))
            out.puts bottom
          end
        end
      else
        'Editing binary files is not supported'
      end
    end

    put "/files/*" do
      path = "#{project_path}/#{params['splat'].join('/')}"
      file = Tint::File.new(path)
      updated_data = normalize(params['data'])

      Tempfile.open('tint-save') do |tmp|
        if updated_data
          tmp.puts updated_data.to_yaml
          tmp.puts '---'
        end
        if params.has_key?('content')
          tmp.puts(params['content'].gsub(/\r\n?/, "\n"))
        else
          file.stream_content(&tmp.method(:puts))
        end
        tmp.flush
        FileUtils.mv(tmp.path, path, force: true)
      end

      g = Git.open(project_path)
      g.add(path)

      g.status.each do |f|
        if f.path == params['splat'].join('/') && f.type
          g.commit("Modified #{params['splat'].join('/')} via tint")
        end
      end

      redirect to("/files/#{Pathname.new(params['splat'].join('/')).dirname}")
    end

    delete "/files/*" do
      file = params['splat'].join('/')

      g = Git.open(project_path)
      g.remove("#{project_path}/#{file}")
      g.commit("Removed #{file} via tint")

      redirect to("/files/#{Pathname.new(file).dirname}")
    end

  protected

    def render_directory(path)
      erb :"layouts/files" do
        erb :"files/index", locals: { files: Directory.new(path).files }
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

  class Directory
    def initialize(path)
      @path = path
    end

    def files
      files = Dir.glob("#{path}/*").map { |file| Tint::File.new(file) }

      if path != PROJECT_PATH
        parent = Tint::File.new(
          ::File.expand_path("..", Dir.open(path)),
          ".."
        )
        files = files.unshift(parent)
      end

      files
    end

  protected

    attr_reader :path
  end

  class File
    def initialize(path, name=nil)
      @path = path
      @name = name
    end

    def directory?
      ::File.directory?(path)
    end

    def text?
      FileMagic.open(:mime) do |magic|
        magic.file(path).split('/').first == 'text'
      end
    end

    def markdown?
      ['md', 'markdown'].include? extension
    end

    def yml?
      ["yaml", "yml"].include? extension
    end

    def root?
      path == PROJECT_PATH
    end

    def route
      "/files#{path.gsub(/\A#{PROJECT_PATH}/, "")}"
    end

    def name
      @name ||= ::File.basename(path)
    end

    def stream_content
      has_frontmatter = false
      doc_start = 0
      ::File.foreach(path).with_index do |line, idx|
        line.chomp!

        if doc_start < 2
          has_frontmatter = true if line == '---' && idx == 0
          doc_start += 1 if line == '---'
          next if has_frontmatter
        end

        yield line
      end
    end

    def content?
      detect_content_or_frontmatter[0]
    end

    def frontmatter?
      detect_content_or_frontmatter[1]
    end

    def frontmatter
      YAML.safe_load(open(path))
    end

  protected

    def extension
      @extension ||= path.split(/\./).last.downcase
    end

    def detect_content_or_frontmatter
      return @content_or_frontmatter if @content_or_frontmatter

      has_frontmatter = false
      ::File.foreach(path).with_index do |line, idx|
        line.chomp!
        if line == '---' && idx == 0
          has_frontmatter = true
          next
        end

        if has_frontmatter && line == '---'
          return [true, has_frontmatter]
        end
      end

      @content_or_frontmatter = [!has_frontmatter, has_frontmatter]
    end

    attr_reader :path
  end
end
