require "erb"
require "fileutils"
require "pathname"
require "rdoc/generator/markup"
require "rdoc_rest"
require "yaml"

class RDoc::Generator::REST
  VERSION = RDocREST::VERSION
  DESCRIPTION = "Generates documentation for REST APIs"
  GENERATOR_DIR = File.join("rdoc", "generator")

  include ERB::Util
  RDoc::RDoc.add_generator(self)

  def initialize(options)
    @options = options
    @template_dir = Pathname.new(options.template_dir)
    @base_dir = Pathname.pwd.expand_path
    @template_cache = {}
  end

  def parse_metadata(comment, code_object, fields)
    comment.gsub!(/:(#{fields}):([ \t]*)(.+)\n*/) do
      code_object.metadata[$1] = $3
      ""
    end
  end

  def generate(top_levels)
    @output_dir = Pathname.new(@options.op_dir).expand_path(@base_dir)
    @current_file, @current_method = nil, nil

    # Load external routing map in place of in-comment attributes
    route_file = File.join(@base_dir, "/tmp/routes.txt")
    @routes = YAML.load_file(route_file) if File.exists?(route_file)

    @sorted_classes = []

    # Run through every file and parse out any metadata that we use.
    # Can't use the preprocessor data as that's saved per class, and not per method like we need.
    # Figure out what classes and methods we can use beforehand for when we generate the index and the files
    top_levels.each do |file|
      file.classes.each do |klass|
        mkpath = nil

        klass.metadata.clear
        parse_metadata(klass.comment, klass, "class_name|api_status|path")

        # Classes are public by default, but can be forced private if needed
        next if klass.metadata["api_status"] == "private"

        methods = []

        klass.each_method do |method|
          method.metadata.clear
          parse_metadata(method.comment, method, "method_name|api_status|path|http_req")
          # Methods by default are private unless otherwise
          next if method.metadata["api_status"] != "public" || method.visibility != :public

          unless mkpath
            Pathname.new("#{@output_dir}#{method_slug(klass, method)}").dirname.mkpath
            mkpath = true
          end

          methods.push(method)
        end

        @sorted_classes.push([file, klass, methods]) unless methods.empty?
      end
    end

    @sorted_classes = @sorted_classes.sort {|a, b| a[0] <=> b[0]}

    copy_assets
    write_index

    @sorted_classes.each do |file, klass, methods|
      @current_class = klass
      methods.each do |method|
        @current_method = method
        write_method(file, klass, method)
      end
    end
  end

  def copy_assets
    options = {:verbose => $DEBUG_RDOC, :noop => @options.dry_run}
    FileUtils.cp("#{@template_dir}/rdoc.css", ".", options)

    Dir["#{@template_dir}/{js,images}/**/*"].each do |path|
      next if File.directory?(path) or File.basename(path) =~ /^\,/

      dest = Pathname.new(path).relative_path_from(@template_dir)
      dirname = dest.dirname

      FileUtils.mkdir_p(dirname, options) unless File.exists?(dirname)
      FileUtils.cp(@template_dir + path, dest, options)
    end
  end

  def write_index
    title = @options.main_page || "API Index"
    output_file = Pathname.new("#{@output_dir}/index.html")
    asset_prefix = @output_dir.relative_path_from(output_file.dirname)

    @context = binding

    write_file(output_file, "index.rhtml")
  end

  def create_slug(text)
    text = text.downcase
    text.gsub!(/[_\s]/, "-")
    text.gsub!(/[^a-z0-9\-]/, "")
    text.gsub!(/-{2,}/, "-")
    text
  end

  def method_slug(klass, method)
    path = "/#{create_slug(klass.metadata["class_name"] || klass.full_name)}/#{create_slug(method.metadata["method_name"] || method.name)}.html"
    path.gsub!(ENV["STRIP_PATH"], "") if ENV["STRIP_PATH"]
    path
  end

  def write_method(file, klass, method)
    class_name = klass.metadata["class_name"] || klass.full_name
    method_name = method.metadata["method_name"] || method.name.gsub("_", " ").capitalize
    title = "#{class_name} -> #{method_name}"
    title << " | #{@options.title}" unless @options.title.nil?

    output_file = Pathname.new("#{@output_dir}#{method_slug(klass, method)}")
    asset_prefix = @output_dir.relative_path_from(output_file.dirname)
    api_route, @context = @routes && @routes["#{file.relative_name}/#{method.name}"], binding
    current_file, current_method = file, method

    # Default to whatever is set in the API
    unless api_route
      api_route = {:type => method.metadata["http_req"], :path => "#{klass.metadata["path"]}#{method.metadata["path"]}"}
    end

    # Any public API without a set HTTP request type or path is invalid
    if api_route[:type].nil? or api_route[:type] == "" or api_route[:path].nil? or api_route[:type] == "" or api_route[:type] == klass.metadata["path"]
      raise RDoc::Error.new("error generating #{output_file}: Missing either http_req or path to the API")
    end

    write_file(output_file, "page.rhtml")
  end

  def write_file(output_file, to_render)
    content = <<-HTML
<!DOCTYPE html>
<html>
  <head>
    #{render_file("_header.rhtml")}
  </head>

  #{render_file(to_render, "_erbfile")}

  #{render_file("_footer.rhtml")}
</html>
    HTML

    return if @options.dry_run

    output_file.open("w+", 0644) do |io|
      io.set_encoding(@options.encoding) if Object.const_defined? :Encoding
      io.write(content)
    end
  end

  def render_file(path, eout="_erbout")
    if source = @template_cache[path]
      return source.result(@context)
    end

    @template_cache[path] = ERB.new(File.read(@template_dir + path), nil, "<>", eout)
    @template_cache[path].result(@context)
  end

  # Where generated class files go relative to output dir
  def class_dir
    nil
  end

  # Where generated class files go relative to the output dir
  def file_dir
    nil
  end

  # Create base directory structure for generated docs
  def gen_sub_directories
    @output_dir.mkpath
  end
end