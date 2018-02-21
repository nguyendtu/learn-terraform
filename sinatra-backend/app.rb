require 'sinatra'

set :bind, '0.0.0.0'

get "/" do
  "Hello, thinh"
end

get "/health" do
  "OK"
end