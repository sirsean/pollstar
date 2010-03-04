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

# load the configuration
config = YAML::load(File.open('config.yaml'))

# connect to the database
MongoMapper.connection = Mongo::Connection.new(config['db_hostname'])
MongoMapper.database = config['db_name']
if config['db_username']
    MongoMapper.connection[config['db_name']].authenticate(config['db_username'], config['db_password'])
end

before do
    if session["user_id"]
        puts "Authenticated session from #{@env["REMOTE_ADDR"]}: #{session["user_id"]}"
        @current_user = User.find(session["user_id"])

        @flash = session.delete("flash")

        # build the sidebar info
        @sidebar = {
            "username" => @current_user.username,
            "full_name" => @current_user.full_name,
            "account_level" => @current_user.account_level,
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
        :account_level => :free,
        :monthly_rate => 0,
    })
    @user.save

    session["user_id"] = @user.id
    redirect "/select_plan/"
end

get '/select_plan/?' do
    @cheapo_plan_button = config["cheapo_plan_button"]
    @standard_plan_button = config["standard_plan_button"]
    @deluxe_plan_button = config["deluxe_plan_button"]
    haml :select_plan
end

get '/confirm/?' do
    puts "Payment confirmation"
    puts @env["rack.request.query_hash"].inspect
    reason = @env["rack.request.query_hash"]["paymentReason"]

    account_level = :free
    case reason
        when "poll4.me Cheapo Plan"
            account_level = :cheapo
        when "poll4.me Standard Plan"
            account_level = :standard
        when "poll4.me Deluxe Plan"
            account_level = :deluxe
    end

    @current_user.account_level = account_level
    @current_user.monthly_rate = User.get_monthly_rate_by_account_level(account_level)
    @current_user.save

    if [:cheapo, :standard, :deluxe].include?(account_level)
        session["flash"] = "Congratulations! You have signed up for the #{account_level} plan!"
    end
    redirect_url = (session.delete("redirect_url") or "/home/")
    redirect redirect_url
end

get '/abandon/' do
    puts "Abandoning payment"

    @current_user.account_level = :free
    @current_user.monthly_rate = 0
    @current_user.save

    session["flash"] = "You didn't select a plan, so you can continue on the free plan"
    redirect_url = (session.delete("redirect_url") or "/home/")
    redirect redirect_url
end

get '/cancel/' do
    puts "Cancelling plan"

    @current_user.account_level = :free
    @current_user.monthly_rate = 0
    @current_user.save

    session["flash"] = "Sorry you didn't find the service valuable enough. We'd love to hear your feedback to make poll4.me better. Meanwhile, you can continue with the free plan."
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
    if @current_user.max_answers_per_poll
        if answers and answers.count > @current_user.max_answers_per_poll
            @errors << "you must upgrade your account to use more than #{@current_user.max_answers_per_poll} answers"
        end
    end
    if params["chart_type"]
        chart_type = params["chart_type"].to_sym
    else
        chart_type = :bar
    end
    if not [:bar, :pie].include?(chart_type)
        chart_type = :bar
    end
    if chart_type == :pie and not @current_user.can_choose_chart_type?
        chart_type = :bar
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
        :max_votes => @current_user.max_votes_per_poll,
        :chart_type => chart_type,
    })
    if @current_user.poll_duration
        poll.expires_at = Time.now + @current_user.poll_duration
    end
    poll.save

    puts "Created poll: #{poll.id}"

    # TODO: redirect to an openid login screen if they're not already logged in

    redirect "/poll/#{poll.id}/"
end

get '/poll/:poll_id/copy/?' do |poll_id|
    puts "Copying poll: #{poll_id}"

    poll = Poll.find(poll_id)

    if not ((@current_user.id == poll.user_id and @current_user.can_copy_own_polls?) or @current_user.can_copy_all_polls?)
        return redirect "/poll/#{poll_id}/"
    end

    copied_poll = Poll.create({
        :user_id => @current_user.id,
        :copied_poll_id => poll.id,
        :question => poll.question,
        :answers => poll.answers,
        :active => true,
        :created_at => Time.now,
        :max_votes => @current_user.max_votes_per_poll,
        :chart_type => poll["chart_type"],
    })
    if @current_user.poll_duration
        copied_poll.expires_at = Time.now + @current_user.poll_duration
    end
    copied_poll.save

    puts "Copied poll: #{copied_poll.id}"

    redirect "/poll/#{copied_poll.id}/"
end

get '/poll/:poll_id/?' do |poll_id|
    puts "Viewing poll: #{poll_id}"

    @poll = Poll.find(poll_id)
    puts @poll.inspect

    # determine if the user is logged in (if they're not logged in, they can't vote, right?)

    @voted = Vote.has_user_voted_on_poll(@current_user.id, @poll.id)
    @votes = Vote.get_by_poll_id(@poll.id)
    @is_owner = (@poll.user_id == @current_user.id)
    @can_copy = (@is_owner and @current_user.can_copy_own_polls?) or @current_user.can_copy_all_polls?
    @can_edit = ((@is_owner and @current_user.can_edit_own_polls?) and (@votes.count == 0))

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

get '/poll/:poll_id/edit/?' do |poll_id|
    puts "Editing poll: #{poll_id}"

    if not @current_user
        session["redirect_url"] = request.fullpath
        return redirect "/login/"
    end

    @poll = Poll.find(poll_id)

    if @poll.user_id != @current_user.id
        return redirect "/poll/#{poll_id}/"
    end

    @question = @poll.question
    @answers = @poll.answers.map{ |answer| answer["text"] }

    haml :edit_poll
end

post '/poll/:poll_id/edit/?' do |poll_id|
    puts "Editing poll (post): #{poll_id}"

    if not @current_user
        session["redirect_url"] = request.fullpath
        return redirect "/login/"
    end

    @poll = Poll.find(poll_id)

    if @poll.user_id != @current_user.id
        return redirect "/poll/#{poll_id}/"
    end

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
    if @current_user.max_answers_per_poll
        if answers and answers.count > @current_user.max_answers_per_poll
            @errors << "you must upgrade your account to use more than #{@current_user.max_answers_per_poll} answers"
        end
    end
    if params["chart_type"]
        chart_type = params["chart_type"].to_sym
    else
        chart_type = :bar
    end
    if not [:bar, :pie].include?(chart_type)
        chart_type = :bar
    end
    if chart_type == :pie and not @current_user.can_choose_chart_type?
        chart_type = :bar
    end

    if not @errors.empty?
        @question = params["question"]
        @answers = answers
        return haml :edit_poll
    end

    index = -1 # the index starts at -1 because the first answer will increment it to 0 before using it
    @poll.question = params["question"]
    @poll.answers = answers.map{ |answer| { :index => index += 1, :text => answer } }
    @poll["updated_at"] = Time.now
    @poll.max_votes = @current_user.max_votes_per_poll
    @poll["chart_type"] = chart_type
    @poll.save

    puts "Updated poll: #{@poll.id}"

    redirect "/poll/#{@poll.id}/"
end

post '/poll/:poll_id/vote/?' do |poll_id|
    if not @current_user
        session["redirect_url"] = request.fullpath.gsub("/vote", "")
        redirect "/login/"
    else
        puts "Voting on poll: #{poll_id}"
        poll = Poll.find(poll_id)

        if poll.expired?
            return redirect "/poll/#{poll_id}/"
        end

        votes = Vote.get_by_poll_id(poll.id)
        if poll.max_votes and votes.count >= poll.max_votes
            return redirect "/poll/#{poll_id}/"
        end

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
                xml.title "[#{config["site_name"]}] #{@user.username}"
                xml.description "polls by #{@user.full_name}"
                xml.link "http://#{config["site_hostname"]}/user/#{@user.username}/"

                @polls.each do |poll|
                    xml.item do
                        xml.title poll.question
                        xml.link "http://#{config["site_hostname"]}/poll/#{poll.id}/"
                        xml.pubDate Time.parse(poll.created_at.to_s).rfc822()
                        xml.guid "http://#{config["site_hostname"]}/poll/#{poll.id}/"
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

