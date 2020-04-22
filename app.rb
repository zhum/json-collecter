#!/usr/bin/env ruby
# encoding: utf-8

require 'rubygems'
require 'bundler'
Bundler.require(:default)

#require 'sinatra/reloader' if development?
# require './controller'
# require './model'
# require './assets'
# require './helpers'


configure do
  #enable :sessions
  set :json_encoder, :to_json
  #enable :reloader  # <- for production also

#  set :public_folder, File.dirname(__FILE__) + '/static'

#  set :static_cache_control, [:public, max_age: 60 * 60 * 24 * 365]
#  set :bind, '0.0.0.0'
#  set :port, 9998

  set :partial_template_engine, :slim

  set :views, %w(views)

  Slim::Engine.options[:pretty] = true

  enable :cross_origin

  set :allow_origin, :any
  set :allow_methods, [:get, :post, :options]
  set :allow_credentials, true
  set :max_age, "1728000"
  set :expose_headers, ['Content-Type']
  # if development?
  #   also_reload './models/*.rb'
  #   also_reload './controllers/*.rb'
  #   also_reload './helpers/*.rb'
  #   after_reload do warn 'Reloaded!'; end
  # end
end

before do
  #headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, OPTIONS'
  response.headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT'
  response.headers['Access-Control-Allow-Origin'] = '*'
  response.headers['Access-Control-Allow-Headers'] = 'accept, authorization, origin'
end

options '*' do
  response.headers['Allow'] = 'GET,PUT,POST,OPTIONS'
  response.headers['Access-Control-Allow-Headers'] = 'Authorization, Content-Type, Accept, X-User-Email, X-Auth-Token'
  response.headers['Access-Control-Allow-Origin'] = '*'
  200
end


require "./server.rb"
