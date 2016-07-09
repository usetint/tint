require "sinatra"
require "sinatra/reloader" if development?

require "yaml"
require "git"

require "awesome_print"
require "pry"

folder = "/Users/Eric/code/boltmade/ricardas"
data_path = "#{folder}/_data"

helpers do
  def render_stuff(key, value, name)
    if value.is_a? Hash
      key + ": <ul>" + values.map do |key, value|
        "<li>" + render_stuff(key, value, name) + "</li>"
      end.join + "</ul>"
    elsif value.is_a? Array
      "#{key}: <ul>#{render_value(key, value, "#{name}[]")}</ul>"
    else
      "<label>#{key}#{render_value(key, value, name)}</label>"
    end
  end

  def render_value(key, value, name)
    if value.is_a? Array
      value.map { |v| "<li>" + render_value(key, v, name) + "</li>" }.join
    elsif value.is_a? Hash
      value.map do |key, value|
        render_stuff(key, value, "#{name}[#{key}]")
      end.join
    else
      render_input(key, value, name) + "<br>"
    end
  end

  def render_input(key, value, name)
    if [true, false].include? value
      "<input type='checkbox' name='#{name}' #{' checked="checked"' if value} />"
    elsif value.is_a?(String) && value.length > 50
      "<textarea name='#{name}'>#{value}</textarea>"
    else
      "<input type='text' name='#{name}' value='#{value}' />"
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

post "/data/:filename" do
  g = Git.open(folder)
  new_yml = params['data'].to_yaml
  File.open("#{data_path}/#{params['filename']}", "w") do |file|
    file.write new_yml
  end

  g.add("#{folder}/_data/#{params['filename']}")
  g.commit("Modified #{params['filename']} via admin")
  redirect to("/")
end

