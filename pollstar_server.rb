require 'rubygems'
require 'sinatra'
require 'haml'
require 'sass'
require 'mongo'
require 'mongo_mapper'
require 'model/User'
require 'model/Poll'
require 'model/Vote'

enable :sessions

# connect to the database
MongoMapper.connection = Mongo::Connection.new('localhost')
MongoMapper.database = 'pollstar'

before do
    if session["user_id"]
        puts "Authenticated session from #{@env["REMOTE_ADDR"]}: #{session["user_id"]}"
        @current_user = User.find(session["user_id"])

        # build the sidebar info
        @sidebar = {
            "username" => @current_user.username,
            "full_name" => @current_user.full_name,
            "recent_polls" => Poll.get_latest_by_user_id(@current_user.id, 4),
        }
    else
        puts "Unauthenticated request from #{@env["REMOTE_ADDR"]}"
    end
end

get '/stylesheet.css' do
    content_type 'text/css', :charset => 'utf-8'
    sass :stylesheet
end

get '/?' do
    haml :index
end

get '/signup/?' do
    haml :signup
end

post '/signup/?' do
    puts "Registering a new user"
    puts params.inspect

    @errors = []
    # validate fields
    if not params["username"] or params["username"].empty?
        @errors << "username is required"
    end
    if User.username_exists?(params["username"])
        @errors << "username #{params["username"]} is already taken"
    end
    if not params["full_name"] or params["full_name"].empty?
        @errors << "name is required"
    end
    if not params["email"] or params["email"].empty?
        @errors << "email is required"
    end
    if not params["password1"] or params["password1"].length < 4
        @errors << "password must be at least 4 characters"
    end
    if not params["password2"] or params["password2"].length < 4
        @errors << "repeat password must be at least 4 characters"
    end
    if params["password1"] != params["password2"]
        @errors << "passwords must match"
    end

    if not @errors.empty?
        return haml :signup
    end

    @user = User.create({
        :username => params["username"],
        :email => params["email"],
        :password => params["password1"],
        :full_name => params["full_name"],
    })
    @user.save

    session["user_id"] = @user.id
    redirect_url = (session.delete("redirect_url") or "/home/")
    redirect redirect_url
end

get '/login/?' do
    if @current_user
        redirect "/home/"
    else
        haml :login
    end
end

post '/login/?' do
    puts "Logging in"
    puts params.inspect

    user = User.get_by_username_and_password(params["username"], params["password"])

    if user
        session["user_id"] = user.id
        redirect_url = (session.delete("redirect_url") or "/home/")
        redirect redirect_url
    else
        @errors = [ "invalid login" ]
        haml :login
    end
end

get '/logout/?' do
    if @current_user
        session.delete("user_id")
    end
    redirect "/"
end

get '/home/?' do
    if not session["user_id"]
        redirect "/login/"
    else
        puts "Getting polls for user: #{@current_user.id}"
        @polls = Poll.get_by_user_id(@current_user.id)

        votes = Vote.get_by_user_id(@current_user.id)
        @polls_voted_on = Poll.get_by_ids(votes.map{ |vote| vote.poll_id })

        haml :home
    end
end

get '/poll/create/?' do
    if not @current_user
        session["redirect_url"] = request.fullpath
        return redirect "/login/"
    end
    haml :create
end

post '/poll/create/?' do
    if not @current_user
        session["redirect_url"] = request.fullpath
        return redirect "/login/"
    end
    puts "Creating a poll"
    puts params.inspect

    if params["answers"]
        answers = params["answers"].map{ |answer| answer.chomp }.select{ |answer| !answer.empty? }
    end

    # validate inputs
    @errors = []
    if not params["question"] or params["question"].empty?
        @errors << "question is required"
    end
    if not answers or answers.empty?
        @errors << "a poll needs at least one answer"
    end

    if not @errors.empty?
        @question = params["question"]
        return haml :create
    end

    index = -1 # the index starts at -1 because the first answer will increment it to 0 before using it
    poll = Poll.create({
        :user_id => @current_user.id,
        :question => params["question"],
        :answers => answers.
            map{ |answer| { :index => index += 1, :text => answer } },
        :active => true,
        :created_at => Time.now,
    })
    poll.save

    puts "Created poll: #{poll.id}"

    # TODO: redirect to an openid login screen if they're not already logged in

    redirect "/poll/#{poll.id}/"
end

get '/poll/:poll_id/?' do |poll_id|
    puts "Viewing poll: #{poll_id}"

    @poll = Poll.find(poll_id)
    puts @poll.inspect

    # determine if the user is logged in (if they're not logged in, they can't vote, right?)

    @voted = Vote.has_user_voted_on_poll(@current_user.id, @poll.id)
    @votes = Vote.get_by_poll_id(@poll.id)
    @is_owner = (@poll.user_id == @current_user.id)

    # calculate the number of votes on each answer
    @answer_votes = @poll.answers.map{ |answer| 
        { "text" => answer["text"], 
            "num_votes" => @votes.select{ |vote| 
                puts "vote: #{vote["answer_index"]}, answer: #{answer["index"]}"
                vote["answer_index"] == answer["index"] 
            }.length 
        }
    }

    haml :view_poll
end

post '/poll/:poll_id/vote/?' do |poll_id|
    if not @current_user
        session["redirect_url"] = request.fullpath.gsub("/vote", "")
        redirect "/login/"
    else
        puts "Voting on poll: #{poll_id}"
        poll = Poll.find(poll_id)

        answer_index = params["answer"]

        vote = Vote.create({
            :user_id => @current_user.id,
            :user_full_name => @current_user.full_name,
            :username => @current_user.username,
            :poll_id => poll.id,
            :answer_index => answer_index,
        })
        vote.save

        redirect "/poll/#{poll_id}/"
    end
end

get '/user/:username/?' do |username|
    puts "Viewing user page: #{username}"
    @user = User.get_by_username(username)

    if @user
        @polls = Poll.get_by_user_id(@user.id)
        @is_you = (@user.id == @current_user.id)
        votes = Vote.get_by_user_id(@user.id)
        @polls_voted_on = Poll.get_by_ids(votes.map{ |vote| vote.poll_id })

        haml :view_user
    else
        "User #{username} not found"
    end
end

get '/user/:username/polls/?' do |username|
    puts "Viewing user polls: #{username}"
    @user = User.get_by_username(username)
    @polls = Poll.get_by_user_id(@user.id)

    haml :polls
end

get '/user/:username/polls/feed/?' do |username|
    puts "Getting user polls feed: #{username}"
    @user = User.get_by_username(username)
    @polls = Poll.get_by_user_id(@user.id)

    builder do |xml|
        xml.instruct! :xml, :version => '1.0'
        xml.rss :version => "2.0" do
            xml.channel do
                xml.title "[pollstar] #{@user.username}"
                xml.description "Polls by #{@user.full_name}"
                xml.link "http://pollstar.com/user/#{@user.username}/"

                @polls.each do |poll|
                    xml.item do
                        xml.title poll.question
                        xml.link "http://pollstar.com/poll/#{poll.id}/"
                        xml.pubDate Time.parse(poll.created_at.to_s).rfc822()
                        xml.guid "http://pollstar.com/poll/#{poll.id}/"
                    end
                end
            end
        end
    end
end

helpers do
    def list_polls(polls)
        @polls = polls
        haml :partial_list_polls, :layout => false
    end
end

