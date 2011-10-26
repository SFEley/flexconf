$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'flexconf'

# All our tests are in the context of the configs in the 'example' directory.
Dir.chdir(File.join(File.dirname(__FILE__), 'example'))