$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'flexconf'

describe FlexConf do
  before(:each) do
    Dir.chdir(File.join(File.dirname(__FILE__), 'example'))
    @this = FlexConf.new
  end

  describe "access" do    
    it "can read keys as strings" do
      @this['foo'].should == :bar
    end
    
    it "can read keys as symbols" do
      @this[:foo].should == :bar
    end
    
    it "can read keys as method calls" do
      @this.foo.should == :bar
    end
    
    it "can read non-string keys" do
      @this[7].should == 'seven'
    end
    
    it "can read non-string keys as strings" do
      @this['7'].should == 'seven'
    end
    
    it "can read non-string keys as symbols" do
      @this[:'7'].should == 'seven'
    end
    
    it "can read symbol keys as strings" do
      @this['boo'].should == 'far'
    end
    
    it "can read symbol keys as symbols" do
      @this[:boo].should == 'far'
    end
    
    it "always keeps a consistent value in the event of name collisions" do
      @this['zoo'].should == @this[:zoo]
    end
    
    it "knows when it has a key" do
      @this.has_key?('zoo').should be_true
      @this.has_key?(:zoo).should be_true
    end
    
    it "knows when it doesn't have a key" do
      @this.has_key?(:fantastical).should be_false
    end
    
    it "can be iterated" do 
      @this.each do |key, value|
        @this[key].should == value
      end
    end
    
    it "is enumerable" do
      @this.count.should > 0
    end
  end
  
  describe "nesting" do
    it "can return nested variables" do
      @this[:nest]['foo'].should == 'barbar'
    end
    
    it "can return nested variables as method chains" do
      @this.nest.foo.should == 'barbar'
    end
    
    it "can use arbitrary call styles" do
      @this.nest[:renest].bar.should == 'foofoo'
    end
  end
    
  describe "initialization" do
    it "can be given a hash" do
      c = FlexConf.new 'foo' => 17
      c['foo'].should == 17
    end
    
    it "can be given a filename" do
      c = FlexConf.new 'alternate.yml'
      c.this_file.should == 'The alternate in example/alternate.yml'
    end
    
    it "defaults to config.yml" do
      @this['this_file'].should == 'example/config.yml'
    end
    
    it "defaults to overriding from config_local.yml" do
      @this.local_file.should == 'example/config_local.yml'
    end
    
    it "complains if given no parameters and there is no config.yml" do
      Dir.chdir('..')
      lambda {FlexConf.new}.should raise_error(ArgumentError, /config\.yml/)
    end
  end
  
  describe "local overrides" do
    before(:each) do
      @this = FlexConf.new('config.yml', :local => 'alternate.yml')
    end
    
    it "replaces existing values with ones from the local file" do
      @this.this_file.should == 'The alternate in example/alternate.yml'
    end
    
    it "adds new values from the local file" do
      @this[:locally_grown].should == 'Yummy!'
    end
    
    it "still leaves values not referred to alone" do
      @this[:development].foo.should == 'dev-fu'
    end
    
    it "loads the *_local.yml if :local is 'true'" do
      c = FlexConf.new('alternate.yml', :local => true)
      c[:locally_grown].should == 'Blech!'
    end
  end
  
  describe "hash overrides" do
    before(:each) do
      @this = FlexConf.new 'config.yml', :override => {
        'foo' => 'fahrvergnugen',
        :qoo => 'Qatar',
        :nest => {
          :foo => 'yep',
          :renest => 5
        }
      }
    end
    
    it "overrides at the top level" do
      @this.foo.should == 'fahrvergnugen'
    end
    
    it "adds new values" do
      @this.qoo.should == 'Qatar'
    end
    
    it "overrides nested values" do
      @this.nest.foo.should == 'yep'
    end
    
    it "leaves other values alone" do
      @this.nest[:joo].should == 'lepp'
    end
    
    it "can take out full blocks" do
      @this.nest.renest.should == 5
    end
  end
  
  describe "environment variable overrides" do
    before(:all) do
      ENV['FOO'] = 'harrumph'
      ENV['NEST__JOO'] = 'nipper'
      ENV['HAPPY'] = 'go lucky'
      ENV['ZOO'] = '97'
      ENV['YOO'] = 'know who'
    end
    
    describe "stated as an array" do
      before(:each) do
        @this = FlexConf.new('config.yml', :environment => %w{ZOO HAPPY NEST__JOO FRACK})
      end
      
      it "overrides existing values" do
        @this.zoo.should == '97'
      end
      
      it "creates new values" do
        @this[:happy].should == 'go lucky'
      end
      
      it "overrides nested values" do
        @this.nest.joo.should == 'nipper'
      end
      
      it "does nothing with stated variables that don't exist" do
        @this.should_not have_key(:frack)
      end
    end
    
    describe "automatically pulled with :environment => true" do
      before(:each) do
        @this = FlexConf.new('config.yml', :environment => true) 
      end
      
      it "overrides existing values" do
        @this.foo.should == 'harrumph'
      end
      
      it "does NOT create new values" do
        @this.should_not have_key(:happy)
      end
      
      it "overrides nested values" do
        @this[:nest][:joo].should == 'nipper'
      end
    end
    
    describe "by default" do
      it "overrides local overrides from the environment" do
        @this.yoo.should == 'know who'
      end
    end
    
    after(:all) do
      ENV['FOO'] = nil
      ENV['NEST__JOO'] = nil
      ENV['HAPPY'] = nil
      ENV['ZOO'] = nil
      ENV['YOO'] = nil
    end
  end
  
  
  describe "scope limitation" do
    before(:each) do
      @this = FlexConf.new('config.yml', :scope => :development)
    end
    
    it "returns the values in scope" do
      @this.foo.should == 'dev-fu'
    end
    
    it "does not locally override unless explicitly told" do
      @this.yoo.should == 'yuh?'
    end
    
    it "knows nothing about out-of-scope values" do
      lambda {@this.zoo}.should raise_error(NoMethodError)
    end
    
    it "takes local overrides at the top level" do
      c = FlexConf.new('config.yml', :scope => :development, :local => true)
      c.yoo.should == 0.5
    end
  end
end