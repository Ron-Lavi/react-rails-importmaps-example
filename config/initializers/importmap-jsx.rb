#
# Proof of concept - import maps with JSX transpilation.  Can trivially
# be extended to TypeScript and all the languages currently supported
# with Sprockets.
#
# There are two parts to this:
#  * Have `find_javascript_files_in_tree` in importmap-rails to not only
#      find JS files, but also files that can be transpiled to JS.  
#  * Add sprockets JSX transformer, making use of esbuild
#
# Note: as sprockets requires assets to appear in a manifest, this
# proof of concept takes advantage of that as a mechanism for opting
# in to additional file extensions.  Overall flow:
#
# Add *this* file to config/initializers
#
# Add to config/importmap.rb:
#   pin_all_from "app/javascript/components", under: "components"
#
# Add to app/assets/config/manifest.js:
#   //= link_tree ../../javascript/components .jsx
#
# Create your application, and import your components!

require 'open3'

class Importmap::Map
  # determine what extensions to look for by parsing the manifest
  def exts_for_path(path)
    exts = Set.new ['.js']

    # Read the manifest
    config_dir = File.join(Rails.root, 'app/assets/config')
    manifest_file = File.join(config_dir, 'manifest.js')
    manifest = IO.read(manifest_file)

    # Extract extensions from the manifest
    manifest.scan(%r{//=\s+link_\w+\s+(\S+)\s+(\.\S+)}).map do |match|
      link = File.expand_path(match[0], config_dir)
      exts << match[1] if path.relative_path_from(link).to_s =~ /^(\w|\.$)/
    end

    exts
  rescue
    ['.js']
  end

  # find all files matching the manifest in a given path
  def find_javascript_files_in_tree(path)
    files = []

    exts_for_path(path).each do |ext|
      files += Dir[path.join("**/*#{ext}")].collect do |file|
        next if File.directory? file
        Pathname.new(file.chomp(ext) + '.js')
      end
    end

    files.compact
  end
end

module JsxTransformer
  include Sprockets
  VERSION = '1'

  def self.cache_key
    @cache_key ||= "#{name}::#{VERSION}".freeze
  end

  def self.call(input)
    data = input[:data]

    input[:cache].fetch([self.cache_key, data]) do

      out, err, status = Open3.capture3('esbuild', '--sourcemap',
        "--sourcefile=#{input[:filename]}", '--loader=jsx',
        stdin_data: input[:data])

      if status.success? and err.empty?
        out
      else
        raise Error, "esbuild exit status=#{status.exitstatus}\n#{err}"
      end
    end
  end
end

Sprockets.register_mime_type 'application/jsx', extensions: ['.jsx']

Sprockets.register_transformer 'application/jsx', 'application/javascript',
  JsxTransformer