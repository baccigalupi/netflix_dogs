require File.expand_path(File.dirname(__FILE__) + '/spec_helper') 

describe NetflixDogs::Requester do
  before(:all) do 
    NetflixDogs::Requester.config_location = nil
  end
    
  before(:each) do
    @requester = NetflixDogs::Requester.new( 'base_path' )
  end
  
  describe 'credentials' do 
    before(:each) do 
      NetflixDogs::Requester.config_location = nil
    end  
    
    it 'should throw an error if the config file is not found' do 
      lambda { 
        NetflixDogs::Requester.config_location = '/not_here.yml' 
      }.should raise_error
    end
    
    it 'should throw an error if config file doesn\'t contain a key and secret' do 
      lambda{
        NetflixDogs::Requester.config_location = RAILS_ROOT + '/config/bad_data.yml'
      }.should raise_error
    end    
    
    it 'should find the config file in the default location' do
      NetflixDogs::Requester.config_location.should include( 'netflix.yml' )
      File.exists?(NetflixDogs::Requester.config_location).should == true 
    end
      
    it 'should automatically load credentials' do
      NetflixDogs::Requester.credentials['key'].should == 'my_big_key'
      NetflixDogs::Requester.credentials['secret'].should == 'uber_secret'
      NetflixDogs::Requester.key.should == 'my_big_key'
      NetflixDogs::Requester.secret.should == 'uber_secret' 
    end
    
    it 'should have an instance method for key' do 
      credentials = NetflixDogs::Requester.new( 'base_path' )
      credentials.key.should == 'my_big_key'
    end 
    
    it 'should have an instance method for secret' do 
      credentials = NetflixDogs::Requester.new( 'base_path' )
      credentials.secret.should == 'uber_secret'
    end 
    
    # have to load separate real config file for this to go!
    it 'should load credentials from a custom location' do 
      NetflixDogs::Requester.config_location = RAILS_ROOT + '/config/real_netflix.yml'
      NetflixDogs::Requester.config_location.should match(/real_netflix/)
      NetflixDogs::Requester.credentials['key'].should_not == 'my_big_key'
      NetflixDogs::Requester.credentials['secret'].should_not == 'uber_secret'
      NetflixDogs::Requester.key.should_not == 'my_big_key'
      NetflixDogs::Requester.secret.should_not == 'uber_secret'
    end 
    
    it 'should load application_name' do 
      NetflixDogs::Requester.application_name.should == 'Clerkdogs'
    end
    
    it 'should load authorize_callback_url' do
      NetflixDogs::Requester.authorize_callback_url.should == 'http://clerkdogs.com/netflix/access_token'
    end     
  end     
  
  describe 'parameter packaging' do 
    it 'should build query string from a hash' do 
      @requester.add_to_query(
        'pizza' => 'good',
        'beer' => 'plenty'
      ) 
      @requester.query_string.should == 'beer=plenty&pizza=good'
    end 
    
    it 'should build query string with our without the oauth_signature' do
      @requester.add_to_query(
        'pizza' => 'good',
        'beer' => 'plenty',
        'oauth_signature' => 'yup_im_signed!'
      )
      @requester.query_string.should include( 'oauth_signature')
      @requester.query_string( false ).should_not include( 'oauth_signature' )
    end  
    
    it 'should have a query path' do
      @requester.add_to_query( 
        'pizza' => 'good',
        'beer' => 'plenty'
      ) 
      @requester.query_path.should match(/base_path/) 
      @requester.query_path.should match(/\?/) 
      @requester.query_path.should match(/(&)/)
      @requester.query_path.should match(/pizza=good/)
      @requester.query_path.should match(/beer=plenty/)
    end       
    
  end  
  
  describe 'non-user oauth packaging' do
    it 'should have a set of correct auth params' do
      @requester.auth_hash['oauth_consumer_key'].should == 'my_big_key'
      @requester.auth_hash['oauth_signature_method'].should == "HMAC-SHA1"
      @requester.auth_hash['oauth_timestamp'].class.should == Time.now.to_i.class
      @requester.auth_hash['oauth_nonce'].class.should == 1.class
      @requester.auth_hash['oauth_version'].should == '1.0'
    end 
     
    it 'should build those params into an auth query string' do 
      @requester.build_auth_query_string
      @requester.query_string.should match(/oauth_consumer_key=my_big_key/)
      @requester.query_string.should match(/oauth_signature_method=HMAC-SHA1/)
      @requester.query_string.should match(/oauth_timestamp=/)
      @requester.query_string.should match(/oauth_nonce=/)
      @requester.query_string.should match(/oauth_version=1.0/)
    end
      
    it 'should package the auth query url' do
      @requester.add_to_query( 
        'pizza' => 'good',
        'beer' => 'plenty'
      ) 
      @requester.build_auth_query_string
      
      @requester.url.should match(/^http:\/\/api.netflix.com/) 
      @requester.url.should match(/base_path/) 
      @requester.url.should match(/pizza=good/)
      @requester.url.should match(/beer=plenty/)
      @requester.url.should match(/oauth_consumer_key=my_big_key/)
      @requester.url.should match(/oauth_signature_method=HMAC-SHA1/)
      @requester.url.should match(/oauth_timestamp=/)
      @requester.url.should match(/oauth_nonce=/)
      @requester.url.should match(/oauth_version=1.0/)
      @requester.url.should match(/oauth_signature/)
    end
      
    it 'should create a signature' do 
      @requester.add_to_query( 
        'pizza' => 'good',
        'beer' => 'plenty'
      ) 
      @requester.signature.should_not be_nil
    end
    
    
    describe 'authentication calculations' do 
      # Sample parameters taken from flix4r, which builds this kind of auth!
      #
      # {
      #  "oauth_nonce"=>37137, 
      #  "term"=>"sneakers", 
      #  "max_result"=>2, 
      #  "oauth_signature_method"=>"HMAC-SHA1", 
      #  "oauth_timestamp"=>1241641821, 
      #  "oauth_consumer_key"=>"my_big_key", 
      #  "oauth_signature"=>"BaX9f5cXTu1B1pKA5b9md61axak%3D", 
      #  "oauth_version"=>"1.0"
      # }     
      
      before(:each) do
        @requester.base_path = 'catalog/titles'
        @requester.queries = { 
          'max_result' => '2',
          'oauth_consumer_key' => 'my_big_key',
          'oauth_nonce' => '37137',
          'oauth_signature_method' => 'HMAC-SHA1',
          'oauth_timestamp' => '1241641821',
          'oauth_version' => '1.0',
          'term'=> 'sneakers'
        }
      end 
      
      it 'should have a correct signature_key' do 
        @requester.signature_key.should == "uber_secret&" 
      end   
      
      it 'should have a correct signature_base_string' do 
        @requester.signature_base_string.should ==  "GET&http%3A%2F%2Fapi.netflix.com%2Fcatalog%2Ftitles&max_result%3D2%26oauth_consumer_key%3Dmy_big_key%26oauth_nonce%3D37137%26oauth_signature_method%3DHMAC-SHA1%26oauth_timestamp%3D1241641821%26oauth_version%3D1.0%26term%3Dsneakers"
      end  
      
      it 'should create the correct signature' do
        @requester.signature.should == 'BaX9f5cXTu1B1pKA5b9md61axak=' 
      end
      
      it 'should have a correct url' do
        @requester.signature
        @requester.url.should == 'http://api.netflix.com/catalog/titles?max_result=2&oauth_consumer_key=my_big_key&oauth_nonce=37137&oauth_signature=BaX9f5cXTu1B1pKA5b9md61axak%3D&oauth_signature_method=HMAC-SHA1&oauth_timestamp=1241641821&oauth_version=1.0&term=sneakers'                               
      end     
    end  
      
  end  

  describe 'auth relay' do 
    
    describe 'request tokens' do
      before( :all ) do
        user_data = YAML.load( File.open( RAILS_ROOT + '/config/sample_user.yml' ) ) 
        @request_token = OAuth::RequestToken.new( 
          NetflixDogs::Requester.new('users/current', user(user_data) ).oauth_gateway , 
          user_data['request_token'], 
          user_data['request_secret']
        )                         
      end 
      
      it 'should request a request token if the user is not valid' do 
        NetflixDogs::Requester.config_location = RAILS_ROOT + '/config/real_netflix.yml' 
        requester = NetflixDogs::Requester.new( 'users/current', user )
        requester.go( :user )
        requester.request_token.should_not be_nil
        requester.request_token.class.should == OAuth::RequestToken
      end
    
      it 'should construct an authorization url from the request_token' do
        requester = NetflixDogs::Requester.new('users/current', user )
        requester.request_token = @request_token
        redirect_url = requester.oauth_authorization_url 
        redirect_url.should match(/^https:\/\/api-user.netflix.com\/oauth\/login\?/)
        redirect_url.should match(/oauth_token=zmdwx2g7nttz5c255qeytzzp/)
        redirect_url.should match(/oauth_consumer_key=sdxnmq7pc4v342n6jxnqny2a/) 
        redirect_url.should match(/application_name=Clerkdogs/)
        redirect_url.should match(/oauth_callback=http%3A%2F%2Fclerkdogs.com%2Fnetflix%2Faccess_token/)
      end
    
      it 'request should return the redirect url after getting a request token' do
        requester = NetflixDogs::Requester.new('users/current', user )
        redirect_url = requester.go(:user)
        redirect_url.should == requester.oauth_authorization_url
      end 
    end
    
    describe 'access token' do  
      it 'should request an access token if the request token exists'
    end          
        
  end  

end