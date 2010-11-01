require File.dirname(__FILE__) + '/spec_helper'

require 'app'
require 'test/unit'
require 'rack/test'
require 'ruby-debug'   

describe "NOMDB" do         
  

  # TODO Invalid input (ids)    
  # TODO Disallow deleting ingredients in use   
  # TODO Access-Control-Allow-Origin on all methods
  # TODO find out how to fake rack environment, and test aorigin control 
          # "Origin" is the header we want to test. How to fake headers?
            # request.env['']

 
  # maybes
  # TODO try removing JSONP
  # TODO refactor using let()   
  # TODO correct content-type (http://snippets.aktagon.com/snippets/445-How-to-create-a-JSONP-cross-domain-webservice-with-Sinatra-and-Ruby)           
  # TODO should display nonexisting image instead of 404      
  # TODO performance optimization ( denormalize ingredients ) 
  # TODO  Caching    
  #       Access-Control-Max-Age: 3600
   
  
  include Rack::Test::Methods

  def app 
    @app ||= Sinatra::Application
  end
  
  before :each do
      clear_database()     
      test_hosts = ['example0.org', 'example1.org','example2.org', 'example3.org', 'example4.org', '*.example5.org']
      @origin_host = test_hosts[rand(6)] 
      @env = { 'HTTP_ORIGIN' => @origin_host }
  end
  
  describe "when database empty" do
    
    describe 'when trying to GET a recipe' do
      before do                                                                    
        get '/recipes/4ccc3f1feee07a04f00000c6', {}, { 'HTTP_ORIGIN' => @origin_host   }   
      end                             
      
      it 'should return 404' do
        last_response.status.should == 404
      end   
      
      it 'should allow other domains' do
        last_response.headers['Access-Control-Allow-Origin'].should == @origin_host
      end
      
      it 'should work with jsonp callback' do
        get '/recipes/4ccc3f1feee07a04f00000c6?callback=jsonp64327643782378'
      end
    end
    
    describe 'when trying to GET a recipe via a non-allowed host' do
      before do
        get '/recipes/4ccc3f1feee07a04f00000c6', {}, { 'HTTP_ORIGIN' => "hackersheaven.me"   }
      end
      
      it 'should not send an Access-Control-Allow-Origin' do
          last_response.headers['Access-Control-Allow-Origin'].should be_nil 
      end
    end
    
       
    
    describe 'when ingredient is inserted' do
      before :each do
         @test_file_path = test_data_directory + '/chickpeas.png'
         @ingredient_from_post = post_and_parse '/ingredients',  
                                    :name => 'Kikärtor', # swedish word för chickpeas, to test unicode chars
                                    :file => Rack::Test::UploadedFile.new(@test_file_path, 'image/png')
      end     
       
      describe 'when ingredient returned' do                           

        it "should have correct name" do
          @ingredient_from_post['name'].should == "Kikärtor"           
        end
    
        it 'should return a corrent image uri' do
          @ingredient_from_post['image_uri'].should match /ingredients\/.+\/kikartor\.jpg/        
        end
    
        it 'should not expose image_id' do
          @ingredient_from_post['image_id'].should be_nil 
        end
        
         it 'should have allow other domains' do
           
           last_response.headers['Access-Control-Allow-Origin'].should == @origin_host
         end 
           

      end
      
      describe 'when using jsonp callback' do
        it 'should still work' do
          @ingredient_from_post = post_and_parse '/ingredients?callback=jsonp3238732873282', :name => 'Kikärtor'
          @ingredient_from_post['name'].should == "Kikärtor" 
        end
      end 
                                                   
      
      describe 'when retrieving the ingredient back' do
        it 'should have the inserted values' do
          parsed_response = get_and_parse '/ingredients/' + @ingredient_from_post['id']
          parsed_response['name'].should == 'Kikärtor'
          parsed_response['id'].should ==  @ingredient_from_post['id']  
        end 
        
        it 'should be available as JSONP' do
          parsed_response = get_and_parse '/ingredients/' + @ingredient_from_post['id'] + '?callback=jsonp3273267239821'
          parsed_response['id'].should ==  @ingredient_from_post['id']
        end
        
        it 'should have allow other domains' do
          last_response.headers['Access-Control-Allow-Origin'].should == @origin_host 
        end
      end         
      
      describe 'when displaying image of an ingredient' do
        
        before :each do                                             
          get @ingredient_from_post['image_uri']
        end

        it 'should be a smaller jpeg version of the uploaded image' do      
          last_response.headers['Content-Type'].should == "image/jpeg"
          last_response.body.should == optimized_image_data(@test_file_path) 
        end  
        
        it 'should have aggressive cache headers' do
          last_response.headers['Cache-Control'].should == 'max-age=324000, public'
          last_response.headers['ETag'].should == optimized_image_data(@test_file_path).hash.to_s
          last_response.headers['Content-Length'].should == optimized_image_data(@test_file_path).length.to_s
          
        end
                                                                              
      end
      
    end  # describe 'when ingredient is inserted'
    
    describe 'when ingredient is inserted from a non-allowed domain' do 
      
      it 'should not send Access-Control-Allow-Origin header' do
        post_and_parse '/ingredients',  
                                  {:name => 'Hackerpeas' }, 
                                  { 'HTTP_ORIGIN' => 'hackerninjas.dk'}
        last_response.headers['Access-Control-Allow-Origin'].should be_nil
                                   
                                  
      end                           
      
    end 
    
  
  end
  
  describe 'when ingredients exist in the database'
  
    before do
      @chickpeas = post_and_parse '/ingredients', :name => 'Chickpeas', :file => Rack::Test::UploadedFile.new(test_data_directory + "/chickpeas.png", 'image/png')
      @chorizo =   post_and_parse '/ingredients', :name => 'Chorizo'  # not adding files to these for performance reasons
      @parsley =   post_and_parse '/ingredients', :name => 'Parsley'
      @tomatoes =  post_and_parse '/ingredients', :name => 'Tomatoes'
      @aubergine = post_and_parse '/ingredients', :name => 'Aubergine'
    end     
                                            
    describe 'when listing ingredients' do
      before do
        @result = get_and_parse '/ingredients' 
      end                       
      
      it "should return ingredients in alphabetical order" do
        @result[0]['name'].should == 'Aubergine'
        @result[4]['name'].should == 'Tomatoes'
      end
      
      it 'should be available as JSONP' do
        @result = get_and_parse '/ingredients?callback=jsonp3473428398392'
        @result[4]['name'].should == 'Tomatoes'  
      end
      
      it 'should have allow other domains' do
        last_response.headers['Access-Control-Allow-Origin'].should == @origin_host
      end
    end
    
    describe 'when listing ingredients via a non-allowed origin' do
       it 'should not send Access-Control-Allow-Origin header' do
         get '/ingredients', {}, { 'HTTP_ORIGIN' => "crackerplace.fake" }
         last_response.headers['Access-Control-Allow-Origin'].should be_nil
       end
    end     
    
    describe 'when searching for ingredients' do

         it 'should find on exact name' do
           result = get_and_parse '/ingredients/search/Chickpeas'
           result[0]['id'].should == @chickpeas['id']
           result[0]['name'].should == @chickpeas['name']
           result[0]['image_uri'].should == @chickpeas['image_uri'] 
         end   
         
         it 'should find on case insensitive' do
           result = get_and_parse '/ingredients/search/chickpeas'
           result[0]['id'].should == @chickpeas['id']
         end                                         
         
         it 'should find on partial' do
           result = get_and_parse '/ingredients/search/ch'
           result[0]['id'].should == @chickpeas['id']
           result[1]['id'].should == @chorizo['id'] 
           result[2].should be_nil
         end 
         
         it 'should be availiable as JSONP' do
           result = get_and_parse '/ingredients/search/chickpeas?callback=jsonp723273272387'
           result[0]['id'].should == @chickpeas['id']
         end
         
         it 'should have allow other domains' do
           last_response.headers['Access-Control-Allow-Origin'].should == @origin_host
         end
         
         it 'should NOT have index prior to searching' do
           get_collection('ingredients').should_not have_index :field_name => 'name', :direction => :ascending
         end
         
         it 'should HAVE index post to searching' do 
            get '/ingredients/search/x'
            get_collection('ingredients').should have_index :field_name => 'name', :direction => :ascending
         end

    end
    
    describe 'when searching for ingredients via a non-allowed origin' do
       it 'should not send Access-Control-Allow-Origin header' do
         get '/ingredients/search/Chickpeas', {}, { 'HTTP_ORIGIN' => "wewillwewillhackyou.net" }
         last_response.headers['Access-Control-Allow-Origin'].should be_nil
       end
    end
    
    describe 'when updating the the name of an ingredient' do         
      
      before do  
        @ingredient_from_post = post_and_parse "ingredients/#{@chickpeas['id']}", :name => 'Gazpascho bean' 
      end
      
      it 'should have the updated name' do
        @ingredient_from_post['name'].should == 'Gazpascho bean'
      end
      
      it 'should have allow other domains' do
        last_response.headers['Access-Control-Allow-Origin'].should == @origin_host
      end
      
      it 'should be availiable as JSONP' do
        @ingredient_from_post = post_and_parse "ingredients/#{@chickpeas['id']}?callback=jsonp7238732328", :name => 'Gazpascho bean'
        @ingredient_from_post['name'].should == 'Gazpascho bean' 
      end
      
      

      describe 'when you retrieve ingredient back' do 
        before do              
          @chickpeas_from_get = get_and_parse "ingredients/#{@chickpeas['id']}"  
        end 
        
        it 'should have changed name' do
          @chickpeas_from_get['name'].should == 'Gazpascho bean'    
        end
        
        it 'should have changed url' do                    
          @chickpeas_from_get['image_uri'].should match /ingredients\/.+\/gazpascho-bean\.jpg/
        end   

        
      end  
     
    end 
    
    describe 'when updating the the name of an ingredient via a non-allowed origin' do
       it 'should not send Access-Control-Allow-Origin header' do
         post "ingredients/#{@chickpeas['id']}", { :name => 'Gazpascho bean' }, { 'HTTP_ORIGIN' => "crackerplace.fake" }
         last_response.headers['Access-Control-Allow-Origin'].should be_nil
       end
    end
    
    describe 'when updating the image of an ingredient' do
      before do                                                     
        #FIXME: Change this to chickpeas2
        @new_test_image_path = test_data_directory + "/chorizo.jpg"
        @old_image_uri = @chickpeas['image_uri']
        @returned_ingredient = post_and_parse "ingredients/#{@chickpeas['id']}", :file => Rack::Test::UploadedFile.new(@new_test_image_path, 'image/jpeg') 
      end
      
      it 'should have the new image' do       
        get @returned_ingredient['image_uri']
        last_response.body.should == optimized_image_data(@new_test_image_path)
        
      end
      
      it 'should have deleted the old image' do
        get @old_image_uri                   
        last_response.status.should == 404
        last_response.body.length.should == 0        
      end 
      
    end
    
    describe 'when an ingredient is deleted' do
      before do
        @deleted_ingredient = delete_and_parse '/ingredients/' + @chickpeas['id']
      end
      
      it 'should return the deleted ingredient' do
        @deleted_ingredient['id'].should == @chickpeas['id']
        @deleted_ingredient['name'].should == @chickpeas['name']
      end
      
      it 'should not be retrievable' do
        get "/ingredients/#{@deleted_ingredient['id']}"
        last_response.status.should == 404
      end
      
      it 'should have deleted the image as well' do 
        get @deleted_ingredient['image_uri']
        last_response.status.should == 404
      end
      
      it 'should have allow other domains' do
        last_response.headers['Access-Control-Allow-Origin'].should == @origin_host
      end 
      
      it 'should be available as JSONP' do    
        # we delete chorizo here, since we can't delete chickpeas twice
        @deleted_ingredient = delete_and_parse '/ingredients/' + @chorizo['id'] + '?callback=jsonp23762738732'
        @deleted_ingredient['id'].should == @chorizo['id']  
      end
    end
    
    describe 'when an ingredient is deleted via a non-allowed origin' do
       it 'should not send Access-Control-Allow-Origin header' do
         delete '/ingredients/' + @chickpeas['id'], {}, { 'HTTP_ORIGIN' => "lolhats.hackers.com" }
         last_response.headers['Access-Control-Allow-Origin'].should be_nil
       end
    end
    
    describe 'when an ingredient without image is deleted' do
      it 'should not be retrievable' do       
        delete '/ingredients/' + @chorizo['id']
        get "/ingredients/#{@chorizo['id']}"
        last_response.status.should == 404
      end  
    end
    
    describe 'when there is a recipe in the database' do
      before do
        @existing_recipe = post_and_parse '/recipes',   
          :name =>  'Chorizo and Chickpeas', 
          :ingredient_ids => [ @chickpeas['id'], @chorizo['id'], @parsley['id'], @tomatoes['id'] ].join(',')
      end
      
      describe 'when updating the the name of an ingredient used by the recipe' do         

        before do  
          post "ingredients/#{@chickpeas['id']}", :name => 'Gazpascho bean'
          @existing_recipe = get_and_parse "/recipes/#{@existing_recipe['id']}"     
        end
        
        it 'should change ingredient name in the recipe' do
          @existing_recipe['ingredients'][0]['name'].should == 'Gazpascho bean'
        end                                                            
        
        it 'should change image uri in the recipe' do
          @existing_recipe['ingredients'][0]['image_uri'].should match /ingredients\/.+\/gazpascho-bean\.jpg/
        end
          
      end
        
    end
        
    
  
    describe "when a recipe is created" do
    
      before do
                                                      
        ingredient_ids = [ @chickpeas, @chorizo, @parsley, @tomatoes ].collect { |i| i['id'] } 
        @comma_separated_string_of_ingredient_ids =  ingredient_ids.join(',')
        @existing_recipe = post_and_parse '/recipes', 
                                          :name =>  'Chorizo and Chickpeas', 
                                          :ingredient_ids => @comma_separated_string_of_ingredient_ids
      end 
      
      it 'should get values assigned' do
        @existing_recipe['id'].should_not be_nil
        @existing_recipe['name'].should == 'Chorizo and Chickpeas'
        @existing_recipe.should contain_ingredients( [ @chickpeas, @chorizo, @parsley, @tomatoes ] )   
      end    
      
      
      it 'should have allow other domains' do
        last_response.headers['Access-Control-Allow-Origin'].should == @origin_host
      end
      
      it 'should be available as JSONP' do
        @existing_recipe = post_and_parse '/recipes?callback=jsonp45376437468', 
                                          :name =>  'Chorizo and Chickpeas', 
                                          :ingredient_ids => @comma_separated_string_of_ingredient_ids
        @existing_recipe['name'].should == 'Chorizo and Chickpeas'                       
                                          
      end
      
      describe '"when a recipe is created via a non-allowed origin' do
         it 'should not send Access-Control-Allow-Origin header' do
           post '/recipes', { :name =>  'Chorizo and Chickpeas' }, { 'HTTP_ORIGIN' => "localhose" } 
           last_response.headers['Access-Control-Allow-Origin'].should be_nil
         end
      end
           
      
      describe 'when retrieving it' do
        before do
          @existing_recipe = get_and_parse '/recipes/' + @existing_recipe['id']
        end
         
        it 'should have the values assigned' do
          @existing_recipe['id'].should_not be_nil
          @existing_recipe['name'].should == 'Chorizo and Chickpeas'
          @existing_recipe.should contain_ingredients( [ @chickpeas, @chorizo, @parsley, @tomatoes ] )
        end  
        
        it 'should have allow other domains' do
          last_response.headers['Access-Control-Allow-Origin'].should == @origin_host
        end
        
        it 'should be availiable as JSONP' do
          @existing_recipe = get_and_parse '/recipes/' + @existing_recipe['id'] + "?callback=jsonp7287323287828"
          @existing_recipe['name'].should == 'Chorizo and Chickpeas'
        end                            
      end
      
      
      describe 'when updating name and ingredients' do
        before do
          @cherry_tomatoes = post_and_parse '/ingredients', :name => 'Cherry tomatoes'
          # FIXME create new_ingredients array and use some ruby magic to update it 
                                                      
          new_ingredients = [ @chickpeas, @chorizo, @parsley, @cherry_tomatoes ]
          @comma_separated_string_of_ingredient_ids = new_ingredients.collect{ |i| i['id'] }.join(',')
      
          @recipe_from_post = post_and_parse   '/recipes/' + @existing_recipe['id'],
            :name => 'Chorizo, Chickpeas and Cherry tomatoes',
            :ingredient_ids => @comma_separated_string_of_ingredient_ids
        end 
        
        it 'should return with updated values' do
          @recipe_from_post['id'].should_not be_nil
          @recipe_from_post['name'].should == 'Chorizo, Chickpeas and Cherry tomatoes'
          @recipe_from_post.should contain_ingredients( [ @chickpeas, @chorizo, @parsley, @cherry_tomatoes ] )
        end
        
        it 'should have allow other domains' do
          last_response.headers['Access-Control-Allow-Origin'].should == @origin_host
        end
        
        it 'should be availiable as JSONP' do
           @recipe_from_post = post_and_parse   '/recipes/' + @existing_recipe['id'] + "?callback=jsonp8847838784387",
              :name => 'Chorizo, Chickpeas and Cherry tomatoes',
              :ingredient_ids => @comma_separated_string_of_ingredient_ids  
           @recipe_from_post['name'].should == 'Chorizo, Chickpeas and Cherry tomatoes' 
        end
        
        describe 'when retrieving it back' do
          it 'should have the updated values' do
            recipe_from_get = get_and_parse '/recipes/' + @recipe_from_post['id']
            recipe_from_get['id'].should_not be_nil
            recipe_from_get['name'].should == 'Chorizo, Chickpeas and Cherry tomatoes'
            recipe_from_get.should contain_ingredients( [ @chickpeas, @chorizo, @parsley, @cherry_tomatoes ] )
          end       
        end
        
      end # describe 'when updating name and ingredients' 
      
      describe 'when updating name and ingredients via a non-allowed origin' do
         it 'should not send Access-Control-Allow-Origin header' do
           post '/recipes/' + @existing_recipe['id'], { :name => 'Chorizo, Chickpeas and Cherry tomatoes' }, { 'HTTP_ORIGIN' => "localhorse" } 
           last_response.headers['Access-Control-Allow-Origin'].should be_nil
         end
      end
                                
      it 'should be possible to update only recipe name' do

        recipe_from_post = post_and_parse '/recipes/' + @existing_recipe['id'],
          :name => 'Chorizo, Chickpeas and Cherry tomatoes'           
        recipe_from_get = get_and_parse '/recipes/' + recipe_from_post['id']

        recipe_from_post['id'].should_not be_nil
        recipe_from_post['name'].should == 'Chorizo, Chickpeas and Cherry tomatoes'
      
        recipe_from_get['id'].should_not be_nil
        recipe_from_get['name'].should == 'Chorizo, Chickpeas and Cherry tomatoes'

        recipe_from_post.should contain_ingredients( @existing_recipe['ingredients'] )
        recipe_from_get.should contain_ingredients( @existing_recipe['ingredients'] )

      end

      it 'should be possible to update only ingredients' do

        cherry_tomatoes = post_and_parse '/ingredients', :name => 'Cherry tomatoes'

        recipe_from_post = post_and_parse   '/recipes/' + @existing_recipe['id'],
        :ingredient_ids => [ @chickpeas['id'], @chorizo['id'], @parsley['id'], cherry_tomatoes['id'] ].join(',')         
        recipe_from_get = get_and_parse '/recipes/' + recipe_from_post['id']

        recipe_from_post['id'].should be
        recipe_from_post['name'].should == 'Chorizo and Chickpeas'
      
        recipe_from_get['id'].should be
        recipe_from_get['name'].should == 'Chorizo and Chickpeas'
      
        #TODO: Find out how to use custom matchers (have) on arrays
        recipe_from_post.should contain_ingredients([@chickpeas, @chorizo, @parsley, cherry_tomatoes])
        recipe_from_get.should contain_ingredients([@chickpeas, @chorizo, @parsley, cherry_tomatoes])

      end
                 
       
    
      describe 'when the recipe is deleted' do
      
        before do
          @deleted_recipe = delete_and_parse '/recipes/' + @existing_recipe['id']
        end
      
        it 'should return the deleted recipe' do
          @deleted_recipe['name'].should == @existing_recipe['name']
          @deleted_recipe['id'].should == @existing_recipe['id']
        end
        
        it 'should have allow calling origins' do      
          last_response.headers['Access-Control-Allow-Origin'].should == @origin_host
        end
        
        it 'should be availiable as JSONP' do
          @existing_recipe = post_and_parse '/recipes',  :name =>  'Chorizo and Chickpeas' # re-create it first!
          @deleted_recipe = delete_and_parse '/recipes/' + @existing_recipe['id'] + "?callback=jsonp7438327"
          @deleted_recipe['id'].should == @existing_recipe['id']
        end
      
        it 'should not be retrievable' do
          retrieved_recipe = get_and_parse '/recipes/' + @deleted_recipe['id']
          retrieved_recipe.should be_nil
        end
      
        it 'should not cascade to ingredients' do
          # there is only need for checking one
          chickpeas = get_and_parse '/ingredients/' + @chickpeas['id']
          chickpeas.should_not be_nil 
        end
    
      end
      
      describe 'when the recipe is deleted via a non-allowed origin' do
         it 'should not send Access-Control-Allow-Origin header' do
           delete '/recipes/' + @existing_recipe['id'], {}, { 'HTTP_ORIGIN' => "localwhore.backdoor" } 
           last_response.headers['Access-Control-Allow-Origin'].should be_nil
         end
      end
      
    
    end  # describe "when a recipe is created"
    
    describe 'when a recipe is created without ingredients' do       
      
      before do
        @new_recipe = post_and_parse '/recipes', :name =>  'Chorizo and Chickpeas'
      end      
      
      it 'should have the assigned values' do
        @new_recipe['name'].should == 'Chorizo and Chickpeas' 
      end
      
      it 'should be retrievable' do
        recipe_from_get = get_and_parse '/recipes/' + @new_recipe['id']
        recipe_from_get['name'].should == 'Chorizo and Chickpeas' 
      end
      
    end
    
  end #  describe "NOMDB"
  
  

  
  
  private
  
  def delete_and_parse(url, env = @env)
    delete url, {}, env
    parse_sinatra_response(last_response.body)
  end

  def post_and_parse(url, params = {}, env = @env)
    post url, params, env 
    parse_sinatra_response(last_response.body)
  end

  def get_and_parse(url, params = {}, env = @env)
    get url, params, env
    parse_sinatra_response(last_response.body)
  end
  
  RSpec::Matchers.define :contain_ingredients do |ingredients_to_match|                       
    # Check input
    raise 'ingredients_to_match must contain ingredients' if ingredients_to_match.length == 0
    
    match do |recipe|
      missing_ingredient = false
      ingredients_to_match.each do |ingredient_to_match|     
        
        raise 'ingredients_to_match must not contain nil' if ingredient_to_match.nil?     
        matches = recipe['ingredients'].select do |recipe_ingredient|
          ingredient_to_match['name'] == recipe_ingredient['name'] and  
          ingredient_to_match['id'] == recipe_ingredient['id']
        end                   
        missing_ingredient = true if matches.length == 0     
        
      end 
      !missing_ingredient 
    end 
  end
  
  RSpec::Matchers.define :have_index do |options|                       

    raise 'options must supply :field_name' if not options[:field_name]
    raise 'options must supply :direction (:ascending or :descending)' if not ( options[:direction] == :descending or 
                                                                                options[:direction] == :ascending )   
    match do |collection| 
          
        raise 'accepts only Mongo::Collection' if not collection.is_a? Mongo::Collection              
        indexes = collection.index_information 
        found_index = false
        indexes.each do |index_row|                                 
          index = index_row[1]                     
          index_direction = index['key'][options[:field_name]]
          if ((index_direction == 1) and (options[:direction] == :ascending)) or  
             ((index_direction == -1) and (options[:direction] == :descending))    
                found_index = true  
          end
        end
        found_index
    end 
  end 
  
  
   
  
  
  

