def get_by_id(collection_name, id)
  id = BSON::ObjectId(id) if not id.kind_of? BSON::ObjectId
  get_collection(collection_name).find_one :_id => id
end      

def remove_by_id(collection_name, id)
  id = BSON::ObjectId(id) if not id.kind_of? BSON::ObjectId
  get_collection(collection_name).remove :_id => id
end      

def grid
  Mongo::Grid.new(db_connection)
end

def get_collection(collection_name)
  db_connection.collection(collection_name)
end            

def db_connection
  @connection = Mongo::Connection.new("localhost").db("nom_dev") if @connection == nil
  @connection
end    

def clear_database
  # Clear database (this is much faster than dropping and recreating db)
  db = Mongo::Connection.new("localhost").db("nom_dev")
  db.collections.each do |collection|
    db.drop_collection(collection.name) if collection.name != 'system.indexes'
  end
end