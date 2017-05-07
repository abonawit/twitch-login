#
# Copyright 2017 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"). You may not use this file except in compliance with the License. A copy of the License is located at
#
#    http://aws.amazon.com/apache2.0/
#
# or in the "license" file accompanying this file. This file is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
#

# Define our dependencies
require 'sinatra'
require 'oauth2'
require 'securerandom'
require 'json'

# Define our configurations.  This is only done for illustrative purposes. 
# It is STRONGLY recommended that you do not store application secrets on your file system or in your source code.
configure do
  enable :sessions
  enable :logging
  set :session_secret, '<SOME SECRET HERE>'        # Your session secret
  set :client_id,      '<YOUR CLIENT ID HERE>'     # The client ID assigned when you created your application
  set :client_secret,  '<YOUR CLIENT SECRET HERE>' # The client secret assigned when you created your application
  set :redirect_uri,   '<YOUR REDIRECT URL HERE>'  # You can run locally with - http://localhost:4567/auth/twitch/callback
  set :scope,          'user_read'                 # The scopes you would like to request 
end

def client
  OAuth2::Client.new(settings.client_id, settings.client_secret, 
    :site => 'https://api.twitch.tv', :authorize_url => '/kraken/oauth2/authorize', :token_url => '/kraken/oauth2/token')
end

# Set route to start OAuth link, this is where you define scopes to request
get '/auth/twitch' do
   session[:state] = SecureRandom.base64
   redirect client.auth_code.authorize_url(:redirect_uri => settings.redirect_uri, :state => session[:state], :scope => settings.scope)
end

# Set route for OAuth redirect
get '/auth/twitch/callback' do
  # Check given state against previously stored one to mitigate CSRF attack
  if session[:state] === params[:state]
    access_token = client.auth_code.get_token(params[:code], :redirect_uri => settings.redirect_uri)
    session[:access_token] = access_token.token
  else
    session.delete(:state)
  end
  redirect '/'
end

# If user has an authenticated session, display it, otherwise display link to authenticate
get '/' do
  if session[:access_token]
    access_token = OAuth2::AccessToken.new(client, session[:access_token], :header_format => 'OAuth %s')
    puts access_token
    puts access_token[:token]
    response = access_token.get("/kraken/user", :headers => {
      'Client-ID' => settings.client_id, 
      'Accept' => 'application/vnd.twitchtv.v5+json'})
    profile = JSON.parse(response.body)
    puts profile
    puts profile["display_name"]
    erb :index_authenticated, :locals => {'profile' => profile, 'access_token' => access_token}
  else
    erb :index_unauthenticated
  end
end
