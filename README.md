# FlexConf #

FlexConf is a simple configuration utility that does its job and gets out of
your way. It reads settings from a hash or YAML file (`config.yml` by default)
with optional overrides from a `*_local.yml` file and from environment
variables. Settings can be retrieved as indifferent hash values (config['foo']
or config[:foo]) or method calls (config.foo).

Simplicity and portability are major design goals. The code is a single
lightweight class (roughly 100 lines of code) with no external gem
dependencies. The spec suite passes in Ruby 1.8.7, 1.9.2, 1.9.3, and current
(October 2011) versions of JRuby and Rubunius.

## Installation ##

Come on kids, you know this one:

    gem install flexconf

Or do what the sophisticated urbanite does and use Bundler:

    # In your Gemfile:
    gem 'flexconf'
    
## Loading From a Hash ##

This is the simplest approach for small use cases.  Just create a Ruby file
and declare your values:

    require 'flexconf'
    
    CONFIG = FlexConf.new {
      my_arbitrary_username: 'joeschmoe',   # Ruby 1.9 syntax
      my_arbitrary_password: 'blah1234',
      
      :another_thing => 'here',             # Classic 'hashrocket' syntax
      'some_number'  => 24,
      
      nested: {
        'mommy_bird' => 'Tweet!',
        'baby_bird'  => 'Facebook.'
      }
    }

This usage mode has no options and no overrides.  If you need to calculate
or merge anything, just do it before you create the FlexConf object.

All keys are converted to symbols on creation, regardless of their original
type. Yes, that means numbers and arrays and other crazy objects too. This is
for _configuration data;_ we're not trying to be a general-purpose hash.

Values are left alone, except that nested hashes are converted into nested
FlexConf objects. 

## Loading from YAML ##

This is the more flexible usage, with multiple options for scoping and 
overrides:

    require 'flexconf'
    
    CONFIG = FlexConf.new '../mysettings.yml',  # Core filename (include path if needed)
        scope: :development,            # Only load values from the 'development' key
        local: 'mysettings_local.yml',  # Merge in values from this other YAML file
        environment: true,              # Allow overrides from environment variables
        override: { :cache => 'Dummy' } # Also override from the provided hash
        
Or, if it suits your needs, you could simply take the defaults:

    require 'flexconf'
    
    CONFIG = FlexConf.new
    
...which is equivalent to:

    CONFIG = FlexConf.new 'config.yml', local: 'config_local.yml', environment: true

As with hash loading, all keys are converted to symbols on creation and the
object is read-only after it's created. Options are described in detail after
the "Using It" section.

## Using It ##

The FlexConf object supports both the 'indifferent hash' style and the 'method
call' style for accessing configuration values. Both are interchangeable and
recursive:

    CONFIG[:some_number]      #=> 24
    CONFIG['some_number']     #=> 24
    CONFIG.some_number        #=> 24
    
    CONFIG[:nested]['mommy_bird']   #=> 'Tweet!'
    CONFIG['nested'][:mommy_bird]   #=> 'Tweet!'
    CONFIG.nested.mommy_bird        #=> 'Tweet!'
    CONFIG.nested[:baby_bird]       #=> 'Facebook.'

If you've spent a little time working with [Chef](http://wiki.opscode.com),
this level of looseness will probably seem familiar. Their attribute access
patterns were a direct inspiration for FlexConf. (If you've spent a _lot_ of
time working with Chef, you're probably at the sanatorium and _nothing_ seems
familiar.)

FlexConf objects are _very loosely_ duck-typed to Hashes, but are not subclasses of Hash.  They publicly support the following methods:

* `[]` (your friend the accessor)
* `has_key?`
* `each` (returns key and value, just like Hash)
* the Enumerable mixin

FlexConf objects are _read-only_ once they're initialized. You can't change
any values later. This is by deliberate design decision. (If you need to muck
with your application's configuration after it's up and running, it's not
'configuration' any more, it's mutable state and you should be paying more
attention to it than this.)

## Options ##

Options that can be passed at initialization are as follows (and only work in YAML mode):

### :scope ###

Use this for Rails-style environments. The provided value must be a top-level
key in the main YAML file. The key/value pairs nested beneath it will become
top-level structures for the FlexConf configuration, and the rest of the file
will be ignored. Note that this happens _after_ the YAML library does its
processing, so if your file looks like:

    defaults: &defaults
      foo: 'bar'
      yoo: 'yar'
      something_else: 17
      
    test:
      << *defaults
      foo: 'car'

...and so forth, a `:scope => :test` option will still do the right thing.

Scope limiting applies _only_ to the main YAML file and occurs before any
other options are handled. Overrides from a 'local' YAML file, environment
variables, or a supplied hash are assumed already to be in the desired scope
and won't be transformed.

### :local ###

This option addresses the common use case of supplying sensitive data
(passwords, etc.) or user-specific development machine settings in a secondary
YAML file that is _not_ checked into source control. The options from this
secondary file are merged into the main configuration. There are two ways to
use it:

* `:local => 'path/somefile.yml'` looks for the given file and loads it if it
  exists.

* `:local => true` appends '_local' to the base filename of the main YAML
  file, and loads it if it exists in the same directory. (E.g., if your
  primary file was `/conf/amazon_settings.yml`, it would look for
  `/conf/amazon_settings_local.yml`.)

In either case, no error will be raised if the file is not found.

### :override ###

This option takes a hash value and merges it into the configuration _after_
the main YAML file and `:local` file are processed. It works just like the
"Loading From a Hash" section described above.  'Nuff said.

### :environment ###

This option allows values to be passed in from the command line or from external processes (your Web server, et cetera) by means of environment variables. The environment variable name is lowercased and symbolized, and nested keys can be pointed to by separating them with a double underscore (`__`).  The intended use case is something like:

    $ AMAZON__ACCESS_ID=blahblah AMAZON__SECRET_KEY=yaddayadda rake deploy:thingy
    
If the Rake task is using a FlexConf anywhere with the `:environment` option set, then those two variables will automatically be merged into `CONFIG[:amazon][:access_id]` and `CONFIG[:amazon][:secret_key]`. As with the `:local` option, there are two ways to use it:

* `:environment => ['SOME_ENV_VAR', 'ANOTHER_ENV_VAR']` merges in _only_ the
  environment variables specified in the given array. Keys that didn't
  previously exist are created (including nested paths). The rest of the
  environment is ignored, and no error is raised if the variables aren't
  actually set. This is the most secure way to use it if you can plan ahead
  for which configuration values may need changing at runtime.

* `:environment => true` scans the entire environment, but _only_ updates keys
  that already exist (from the main YAML file or some other override). New
  keys are not created, to prevent polluting your configuration with settings
  like `[:home]` and `[:_]` and `[:grep_options]`. This is a useful shortcut
  if you want your entire configuration to be alterable at runtime, but make
  sure you don't have any top-level key names that may collide with common
  Unix names.





