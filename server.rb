#require "ostruct"

get '/info.json' do
  '{"status": "ok"}'
end

get '/slurm.json' do 
    headers({'X-Frame-Options' => 'SAMEORIGIN', 'Timing-Allow-Origin' => '*'})
    cache_control :private, :max_age => 1200
    content_type "application/json"
    f = File.open("static/slurm.json") 
    f.read 
end 

