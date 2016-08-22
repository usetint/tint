require_relative "resource"

module Tint
	class Directory < Resource
		def resource(path)
			site.resource(relative_path.join(path))
		end

		def children
			@children ||= begin
				children = exist? ? path.children(false).map(&method(:resource)) : []

				if (hidden_paths = site.config["hidden_paths"])
					hidden = Pathname.glob(
						hidden_paths.flat_map { |p| [path.join(p), site.cache_path.join(p)] }
					)
					children = children.reject { |child| hidden.include?(child.path) }
				end

				if relative_path.to_s != "."
					parent = self.class.new(site, relative_path.dirname, "..")
					children.unshift(parent)
				end

				children.sort_by { |f| [f.directory? ? 0 : 1, f.name] }
			end
		end

		def to_h(include_children=true)
			if include_children
				super.merge(
					children: children.map { |f| f.to_h(false) }
				)
			else
				super
			end
		end
	end
end
