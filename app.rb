require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/json"

require "yaml"
require "json"

require "git"

require "awesome_print"
require "pry"

project_path = "/Users/Eric/code/projects/tint-demo"

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

get "/" do
  files = Dir.glob("#{project_path}/*")
  erb :index, locals: { files: files, root: project_path }
end

get "/files/:path" do
  if File.directory?("#{project_path}/#{params['path']}")
    files = Dir.glob("#{project_path}/#{params['path']}/*")
    erb :index, locals: { files: files, root: project_path }
  end
end

get "/files/:folder/:filename" do
  file_path = "#{project_path}/#{params['folder']}/#{params['filename']}"
  data = YAML.load_file(file_path)
  erb :data, locals: { data: data, path: "/files" + file_path.gsub(project_path, "") }
end

def transforms
  {
    "on" => true
  }
end

post "/files/:folder/:filename" do
  folder = params['folder']
  g = Git.open(project_path)
  updated_data = normalize(params['data'])
  new_yml = updated_data.to_yaml
  file_path = "#{project_path}/#{params['folder']}/#{params['filename']}"
  original_data = YAML.load_file(file_path)

  if original_data != updated_data
    File.open(file_path, "w") do |file|
      file.write new_yml
    end

    g.add("#{project_path}/#{params['folder']}/#{params['filename']}")
    g.commit("Modified #{params['filename']} via admin")
  end

  redirect to("/")
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

