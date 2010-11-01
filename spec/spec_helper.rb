require File.join(File.dirname(__FILE__), '../lib', 'app.rb')

require 'rubygems'
require 'sinatra'
require 'rack/test'
require 'rspec'

# set test environment
set :environment, :test
set :run, false
set :raise_errors, true
set :logging, true    


def optimized_image_data(test_file_path)
  # Returns a blob of test_file_path 
  # resized and cropped to 300x300 and converted to JPEG
  photo = Image.read(test_file_path).first
  photo.crop_resized!(300,300) 
  photo.format = 'JPEG'
  photo.to_blob
end



def parse_sinatra_response(body)
    
      return nil if body.empty?
      jsonp_callback = last_request.env['rack.request.query_hash']['callback']
      if jsonp_callback 
        body.should be_jsonp :callback => jsonp_callback
        body = jsonp_to_json :body => body, :callback => jsonp_callback
      end
      
      begin 
        JSON.parse body
      rescue
       # FIXME make this append (and clear it in the begginning of the spec)
       last_error_log_file = File.new(File.dirname(__FILE__) + "/../errors_of_last_response.txt", "w+")
       last_error_log_file.syswrite(last_response.errors)
       debugger
       raise 'Could not parse Sinatra response as JSON, actual error: ' + last_response.errors.to_s  
      end
    
end 

def test_data_directory
  File.dirname(__FILE__) + '/test_data'
end 


RSpec::Matchers.define :be_jsonp do |options|                       
                          
  match do |body|
     json = jsonp_to_json  :body     => body, 
                           :callback => options[:callback]
     json != nil
  end
  
end 

def jsonp_to_json(options) 
  raise 'no :body' if not options[:body]
  jsonp_callback = "callback"
  jsonp_callback = options[:callback] if options[:callback]
  match  = options[:body].match /^#{jsonp_callback}\((.+)\)$/ 
  return match[1] if match
  return nil
end