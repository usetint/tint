require "sinatra"
require "sinatra/reloader" if development?

require "yaml"
require "awesome_print"

data_path = "/Users/Eric/code/boltmade/ricardas/_data"

helpers do
  def render_stuff(key, value)
    if value.is_a? Hash
      key + ": <ul>" + values.map do |key, value|
        "<li>" + render_stuff(key, value) + "</li>"
      end.join + "</ul>"
    elsif value.is_a? Array
      "#{key}: <ul>#{render_value(value)}</ul>"
    else
      "<label>#{key}#{render_value(value)}</label>"
    end
  end

  def render_value(value)
    if value.is_a? Array
      value.map { |v| "<li>" + render_value(v) + "</li>" }.join
    elsif value.is_a? Hash
      value.map do |key, value|
        render_stuff(key, value)
      end.join
    else
      render_input(value) + "<br>"
    end
  end

  def render_input(value)
    if [true, false].include? value
      "<input type='checkbox'#{' checked="checked"' if value} />"
    elsif value.is_a?(String) && value.length > 50
      "<textarea>#{value}</textarea>"
    else
      "<input type='text' value='#{value}' />"
    end
  end
end

get "/" do
  files = Dir.glob("#{data_path}/*")
  erb :index, locals: { files: files }
end

get "/data/:filename" do
  data = YAML.load_file("#{data_path}/#{params['filename']}")
  erb :data, locals: { data: data }
end
