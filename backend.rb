require 'httparty'
require 'rubygems'
require 'sinatra'
require 'mongo'
require 'json/ext' # required for .to_json

configure do
  uri = 'mongodb://chef:zesty@ds037195.mongolab.com:37195/heroku_69r51btd'
  db = Mongo::Client.new(uri)
  set :recipes, db[:recipes]
end

get '/recipes' do
	response['Access-Control-Allow-Origin'] = '*'
  query = URI.encode(params[:q])
	response = HTTParty.get('http://food2fork.com/api/search?key='+randomKey+'&q='+query, {format: :json})
	recipes = response['recipes']
	recipe_hashes = recipes.map do |recipe| 
		{
		  id: recipe['recipe_id'], 
		  type: 'recipe', 
		  attributes: { 
		  	name: recipe['title'], 
		  	image: recipe['image_url'],
		  	publisher: recipe['publisher'],
		  	source: recipe['source_url']
		  }
		}
	end
	return {
		data: recipe_hashes
	}.to_json
end

get '/recipes/:id' do |id|
	response['Access-Control-Allow-Origin'] = '*'
	doc = settings.recipes.find({recipe_id: id}).projection({_id: 0})
	if doc.count == 0
		# if the doc (recipe) is not found in db then go get it
		response = HTTParty.get('http://food2fork.com/api/get?key='+randomKey+'&rId='+id, {format: :json})
		recipe = response['recipe']
		# This maps the ingredients array into a JSONAPI friendly structure
		recipe['ingredients'] = recipe['ingredients'].each_with_index.map do |ingredient, index|
			{id: recipe['recipe_id'] + index.to_s, type: 'ingredient', attributes:{ name: ingredient} }
		end
	 	settings.recipes.insert_one(recipe)
	 	doc = recipe
	else
		doc = doc.to_a.first	
	end
	return {
		data: {
			id: doc['recipe_id'],
			type: 'recipe',
			attributes: {
				name: doc['title'],
				publisher: doc['publisher'],
				image: doc['image_url'],
				source: doc['source_url']
			},
			relationships: {
				ingredients: {
					data: doc['ingredients'].map { |ingred| {id: ingred[:id], type: 'ingredient'} }
				}
			}
		},
		included: doc['ingredients']
	}.to_json
end

def randomKey
	['1d05318655eaf107ac4f4e7ae43eb1e3',
	 '388ed4aeed9adfa738f164f229fbe332',
	 '247cf68fbc736c7de5ab278d86809cf5',
	 '5bc45b0c7ec0cdfa59e897805db81480',
	 'd3b82429ad37d54ba296a0cd7c23354c',
	 'f2537661d29ada8b637f09a39dba802d',
	 '3f4bd64187d0d41c99943db4dfc7e66a',
	 '6879caf8573fd8dfbfcd61e8ef57367b'
	].sample
end
