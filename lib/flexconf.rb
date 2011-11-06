require 'yaml'
require 'forwardable'

# A simple but flexible configuration class. 
class FlexConf
  extend Forwardable
  include Enumerable
  
  # Loads configuration from the supplied source(s).  
  # @overload initialize(hash)
  #   Reads the supplied hash as the entire configuration. No options are handled; you'll
  #   have to make sure the data you provide contains everything you intend it to.
  #   @param [Hash] source The configuration data you want to provide.
  # 
  # @overload initialize(yaml_file, opts)
  #   Loads the given YAML file and optional overrides. 
  #   @param [String, Hash] source A YAML filename. The file must be in the current
  #     directory or a complete path must be given.
  #   @param [optional, Hash] opts Specifies ways in which the supplied data can be
  #     overridden. Overrides are processed in the following order:
  #       1. `:scope` (limit the source configuration namespace)
  #       2. `:local` (secondary '*_local.yml' file)
  #       3. `:override` (hash supplied in code)
  #       4. `:environment` (environment variables)
  #   @option opts [Hash] :override A hash which will be merged over the source 
  #     configuration.
  #   @option opts [String, Boolean] :local A second YAML file containing local data
  #     (presumably outside source control). No error is raised if this file does
  #     not exist. A value of 'true' appends `_local` to the source file's base name,
  #     e.g. `config_local.yml`.
  #   @option opts [Array, Boolean] :environment If given an array of environment
  #     variable names, FlexConf will lowercase the names and then inject or override
  #     them into the configuration. Nested values can be marked by a double underscore
  #     (i.e. 'FOO__BAR' would set a value at [:foo][:bar]).  A value of 'true' scans
  #     all environment variables, but will _only_ override existing values (e.g. an
  #     existing config value at [:aws_access_key] could be overridden by the 
  #     AWS_ACCESS_KEY environment variable.)  
  #     (Use with caution!  Casually setting ':environment => true' if you have
  #     configuration variables such as [:home] or [:path] could have undesired results.)
  #   @option opts [String, Symbol] :scope Limits the configuration to the values
  #     beneath the given top-level key in the YAML source file. Useful for 
  #     Rails-style environment configurations ('development', 'production', etc.) 
  #     Local, environment, and hash overrides are unaffected; they are assumed 
  #     to be already within the intended scope.
  #
  # @overload initialize()
  #   With no parameters, takes a common default case and acts as if you had run
  #   `FlexConf.new('config.yml', :local => 'config_local.yml', :environment => true)`.
  #   Raises an exception if 'config.yml' does not exist.
  def initialize(source=nil, options=nil)
    @data = {}
    case source
    when /.*\.yml/
      source_data = YAML.load_file(source)
      if options && options[:scope]
        flexify scoped(source_data, options[:scope])
      else
        flexify source_data
      end
      handle_overrides(source, options) if options
    when Hash
      flexify source
    when nil
      if File.exists?('config.yml')
        initialize('config.yml', :local => 'config_local.yml', :environment => true)
      else
        raise ArgumentError, "FlexConf can't load: no configuration was given and there is no config.yml file to default to."  
      end
    end
  end
  
  # Returns the value for the given key, which can be a string or a symbol.  Named
  # keys can also be accessed via method calls (i.e. `config.foo`).  Nested 
  # configurations are returned as FlexConf objects.
  def [](key)
    @data[normalize_key(key)]
  end
  
  # Returns true if the given configuration value exists.
  def has_key?(key)
    @data.has_key? normalize_key(key)
  end
  
  # Calls Hash#each on the underlying data structure.
  def_delegators(:@data, :each, :keys, :values, :to_hash)
  
  protected
  def_delegator(:@data, :[]=)   # Needed to merge override data
  
  private
  # We're deconstructionists.  Everything is a symbol!
  def normalize_key(key)
    case key
    when Symbol
      key
    when String
      key.to_sym
    else
      key.to_s.to_sym
    end
  end
  
  # Flatten out, turning keys to symbols and hash values to FlexConfs
  def flexify(hash)
    hash.each do |key, value|
      key = normalize_key(key)
      value = FlexConf.new(value) if value.kind_of?(Hash)
      if @data[key].is_a?(FlexConf)
        merge(@data[key], value)
      else
        @data[key] = value
      end
    end
  end
  
  # Deep merge into existing substructures
  def merge(mine, theirs)
    theirs.each do |key, value|
      if mine.has_key?(key) and value.kind_of?(Hash)
        merge(mine[key], value)
      else
        mine[key] = value
      end
    end
  end
  
  def handle_overrides(source_file, options={})
    local_override(source_file, options[:local]) if options[:local]
    hash_override(options[:override]) if options[:override]
    if options[:environment].respond_to?(:each)
      env_subset = ENV.select {|k,v| options[:environment].include? k}
      environment_override(env_subset, true)
    elsif options[:environment] == true
      environment_override(ENV, false)
    end
  end
  
  def local_override(source_file, local)
    local = File.join(File.join(File.dirname(source_file), File.basename(source_file, '.yml') + '_local.yml')) if local == true
    flexify YAML.load_file(local) if File.exists?(local)
  end
  
  def hash_override(hash)
    flexify hash
  end
  
  
  # Turn 'THIS_LONG__ENVIRONMENT__PATH' to [:this_long, :environment, :path]
  def normalize_envvar(name)
    name.downcase.split('__').map {|e| e.empty? ? nil : e.to_sym}
  end
  
  def get_path(root, names, create_path=false)
    this, remaining = names.first, names[1..-1]
    if remaining.empty?
      root
    elsif root[this].kind_of?(FlexConf)
      get_path(root[this], remaining, create_path)
    elsif create_path and !root.has_key?(this)
      root[this] = FlexConf.new({}) # Create an empty stub for the path
      get_path(root[this], remaining, true)
    else  # The node exists and isn't a FlexConf, or create_path is false
      false
    end
  end
  
  # Override from a provided hash of environment variables. Create new paths
  # or new values only if create=true.
  def environment_override(env, create_key=false)
    env.each do |key, value|
      flexvar = normalize_envvar(key)  # Get an array of symbols representing the path
      if data_path = get_path(@data, flexvar, create_key)
        data_key = flexvar[-1]
        data_path[data_key] = value if data_path.has_key?(data_key) or create_key
      end
    end
  end
  
  def scoped(data, scope)
    # This is before flattening, so we need to check both string and symbol forms
    data[scope] || data[scope.to_s] || data[scope.to_sym]
  end
  
  def method_missing(name, *args, &block)
    self.has_key?(name) ? self[name] : super
  end
end
