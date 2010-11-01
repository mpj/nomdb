require 'rubygems'
require 'sinatra'
require 'mongo'
require 'bson'     
require 'unicode'         
require 'json'       
require 'RMagick'    
include Magick

require 'configuration'
require 'data'
 
require 'ruby-debug'

get '/ingredients' do
  print_access_control_header
  
  ingredients_collection = get_collection("ingredients")
  ingredient_cursor = ingredients_collection.find nil, { :sort => [ :name, :ascending ] }
     
  ingredients = []
  ingredient_cursor.each do |ingredient|
    ingredients.push pretty(ingredient)
  end
  return_json ingredients
  
end
               
post '/ingredients' do
  print_access_control_header 
  upsert_ingredient params
end                                                      

post '/ingredients/:id' do
  print_access_control_header       
  upsert_ingredient params  
end  

# GET /ingredients/123456789/chickpeas.jpg
# This url scheme is not exactly RESTful, but it's very nice for search engines.
get '/ingredients/*/*.jpg' do 
  id = BSON::ObjectId params[:splat][0] 
  content_type "image/jpeg"
  begin
    file = grid.get(id)
  rescue 
    # TODO conditional error   
    return not_found  
  end
  data = file.read
  headers "Cache-Control" => 'max-age=324000, public', "ETag" => data.hash.to_s
  data
    
  
end    

get '/ingredients/:id' do    
  
  print_access_control_header 
  ingredient = get_ingredient params[:id]
  return not_found if ingredient.nil?
  pretty_json(ingredient)
end
       
delete %r{/ingredients/([\w]+)} do
  print_access_control_header 
  id_string = params[:captures].first
  id = BSON::ObjectId id_string
  ingredient = get_ingredient(id)
  remove_ingredient(id)  
  grid.delete ingredient['image_id'] 
  pretty_json(ingredient)
end                                  

get '/ingredients/search/:name' do             
  print_access_control_header
  get_collection('ingredients').create_index([['name', Mongo::ASCENDING]])                                                   
  name_for_searching =  simplify_string(params[:name])
  ingredients_cursor = get_collection('ingredients').find( { 'name_simple' => /^#{name_for_searching}/  } )
  ingredients = []
  ingredients_cursor.each do |ingredient|
    ingredients.push pretty(ingredient)
  end
  return_json ingredients
  
end
    


post '/recipes' do                          
  print_access_control_header
  upsert_recipe params
end

post '/recipes/:id' do
  print_access_control_header          
  upsert_recipe params
  
end

get '/recipes/:id' do
  print_access_control_header
  recipe = get_recipe params[:id]
  return not_found if recipe.nil?
  pretty_json(recipe)
end

delete %r{/recipes/([\w]+)} do
  print_access_control_header 
  id_string = params[:captures].first
  id = BSON::ObjectId id_string 
  recipe = get_recipe(id) 
  remove_recipe(id)
  pretty_json(recipe)
end

private  

def upsert_recipe(params)
  if params[:id] 
    recipe = get_recipe params[:id]
  else
    recipe = {}
  end
   
  recipe['name'] = params[:name] if params[:name]
  if params[:ingredient_ids]
    comma_separated_ingredient_ids = params[:ingredient_ids]
    ingredient_ids = comma_separated_ingredient_ids.split(",")
    recipe['ingredient_ids'] = ingredient_ids
  end
  
  get_collection('recipes').save recipe
  pretty_json(recipe)
  
end

def upsert_ingredient(params)
  if params[:id]
    ingredient = get_ingredient(BSON::ObjectId(params[:id])) 
  else
    ingredient = {}
  end
  
  uploaded_file = params[:file][:tempfile] unless params[:file].nil?    
  if uploaded_file            
    photo = Image.read(uploaded_file.path).first
    photo.crop_resized!(300,300) 
    photo.format = 'JPEG'
    new_image_id = grid.put photo.to_blob, :content_type => "application/jpg"      
    grid.delete ingredient['image_id'] if ingredient['image_id'] # Delete the old image, if any
    ingredient['image_id'] = new_image_id
  end                                
  if not params[:name].nil?
    ingredient['name'] = params[:name]     
    ingredient['name_simple'] = simplify_string params[:name]
  end
  
  get_collection("ingredients").save ingredient                                      
  pretty_json ingredient
end

def print_access_control_header
  # Prints the Access-Control-Allow-Origin header, allowing for cross-domain-AJAX
  # if the origin host exists in configuration settings
  setting = options.allowed_origin_hosts
  hosts = setting.gsub(/[ ]+/,'').split(',')     
  hosts.each do |host|               
    if request.env['HTTP_ORIGIN'] == host
      headers 'Access-Control-Allow-Origin' => request.env['HTTP_ORIGIN'] 
    end 
  end
end       

def return_json(object)                             
  if params[:callback] 
    jsonp = "#{params[:callback]}(#{object.to_json})"
  else
    object.to_json
  end
end
     
def pretty_json(object)    
  return_json(pretty(object)) 
end


def pretty(object)
  fix_id(object)                               

  if not object['image_id'].nil?                                                            
    id = object['image_id'].to_s                                                                                  
    object['image_uri'] = "/ingredients/#{id}/#{object['name_simple']}.jpg"        
    object.delete('image_id')
  end
  has_ingredients = object['ingredient_ids'].nil? == false
  if (has_ingredients) 
    load_ingredients(object)  
    object['ingredients'].each do |ingredient|
      pretty(ingredient)
    end                 
  end 
  object
end


def fix_id(object)
  # Clean the mongo id for better presentation
  return object if not object['id'].nil? # id already fixed
    
  if object[:_id].nil? 
    # id key is a string on get
    object['id'] = object['_id'].to_s
    object.delete('_id')
  else
    # id key is a symbol on insert
    object['id'] = object[:_id].to_s
    object.delete(:_id)
  end
  object
end

def load_ingredients(recipe)   
  # Deletes the ingredient_ids array and replaces
  # it with an array of the real ingredients
  recipe['ingredients'] = []
  recipe['ingredient_ids'].each do |id|
    ingredient = get_ingredient(id)
    fix_id(ingredient)
    recipe['ingredients'].push ingredient
  end
  recipe.delete('ingredient_ids')
  recipe
end


def simplify_string(string)
  # Creates a simplified represenation of a string, used for SEO-friendly urls and index-powered searches.
  decomposed = Unicode.decompose(string) # Convert ü to u and so on
  spaceless = decomposed.gsub(/[ ]+/," ").gsub(/ /,"-")  # replace any spaces with dashes
  spaceless.downcase.delete('^0-9a-z\-') #  make it lowercase and remove any other funky characters      
end
     
     
     
def remove_ingredient(id) 
   remove_by_id 'ingredients', id
end    

def remove_recipe(id) 
   remove_by_id 'recipes', id
end

def get_ingredient(id)
  get_by_id 'ingredients', id
end

def get_recipe(id)
  get_by_id 'recipes', id
end

