require 'rubygems'
require 'sinatra'
require 'haml'
require 'sass'
require 'mongo'
require 'mongo_mapper'
require 'pony'

enable :sessions

# load the configuration
config = YAML::load(File.open('config.yaml'))

# connect to the database
MongoMapper.connection = Mongo::Connection.new(config['db_hostname'])
MongoMapper.database = config['db_name']
if config['db_username']
    MongoMapper.connection[config['db_name']].authenticate(config['db_username'], config['db_password'])
end

# need to load the models AFTER connecting to the database, because of the way MongoMapper sets up indexes
require 'model/Log'
require 'model/User'
require 'model/Poll'
require 'model/Vote'

=begin
Before every single request, we have to do a few things.

Namely, check if the user is logged in, prepare the configuration and environment variables that we're going to use elsewhere, manage the session-based "flash" variable which displays a message to the user just once, load the data for the sidebar (if necessary), and determine whether to show ads for this request.
=end
before do
    @logger = Logger.new(session["user_id"], @env["REMOTE_ADDR"])
    @ip = @env["REMOTE_ADDR"]
    if session["user_id"]
        @logger.debug "Authenticated session from #{@ip}: #{session["user_id"]}"
        @current_user = User.find(session["user_id"])

        @flash = session.delete("flash")

        # build the sidebar info
        @sidebar = {
            "username" => @current_user.username,
            "full_name" => @current_user.full_name,
            "recent_polls" => Poll.get_latest_by_user_id(@current_user.id, 4),
        }

        @show_ads = @current_user.show_me_ads?
    else
        @logger.debug "Unauthenticated request from #{@env["REMOTE_ADDR"]}"
        @show_ads = true
    end
    @pogads = config["pogads"]

    @site_name = config["site_name"]
    @site_hostname = config["site_hostname"]
    @piwik_url = config["piwik_url"]
    @config = config
end

=begin
Compile the Sass stylesheet into CSS and render it.
=end
get '/stylesheet.css' do
    content_type 'text/css', :charset => 'utf-8'
    sass :stylesheet
end

=begin
This just shows the index screen; there's no dynamic data on it.
=end
get '/?' do
    haml :index
end

# define some helpers that we'll use across various views

helpers do
    def list_polls(polls)
        @polls = polls
        haml :partial_list_polls, :layout => false
    end

    def show_ad(ad_name)
        @ad_name = ad_name
        haml :partial_show_ad, :layout => false
    end

    def time_until(date)
        days = ((date - Time.now) / 86400).floor
        "#{days} days"
    end

    def results_chart(answer_votes, chart_type, width, height)
        @answer_votes = answer_votes
        @chart_type = chart_type
        @width = width
        @height = height
        haml :partial_results_chart, :layout => false
    end
end

# load the routes for each module's functionality

load 'routes/user_routes.rb'
load 'routes/feed_routes.rb'
load 'routes/poll_routes.rb'
load 'routes/embed_routes.rb'
load 'routes/plan_routes.rb'
load 'routes/ad_routes.rb'
