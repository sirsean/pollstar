get '/signup/?' do
    haml :signup
end

post '/signup/?' do
    @logger.debug "Registering a new user"
    @logger.debug params.inspect

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

get '/login/?' do
    if @current_user
        redirect "/home/"
    else
        haml :login
    end
end

post '/login/?' do
    @logger.debug "Logging in"
    @logger.debug params.inspect

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
        @logger.debug "Getting polls for user: #{@current_user.id}"
        @polls = Poll.get_by_user_id(@current_user.id)

        votes = Vote.get_by_user_id(@current_user.id)
        @polls_voted_on = Poll.get_by_ids(votes.map{ |vote| vote.poll_id })

        haml :home
    end
end

get '/user/:username/?' do |username|
    @logger.debug "Viewing user page: #{username}"
    @user = User.get_by_username(username)

    if @user
        @polls = Poll.get_by_user_id(@user.id)
        @is_you = (@user.id == @current_user.id)
        votes = Vote.get_by_user_id(@user.id)
        @polls_voted_on = Poll.get_by_ids(votes.map{ |vote| vote.poll_id })
        @show_ads = (@show_ads and @user.show_ads_on_my_polls?)

        haml :view_user
    else
        "User #{username} not found"
    end
end

get '/user/:username/polls/?' do |username|
    @logger.debug "Viewing user polls: #{username}"
    @user = User.get_by_username(username)
    @polls = Poll.get_by_user_id(@user.id)
    @show_ads = (@show_ads and @user.show_ads_on_my_polls?)

    haml :polls
end


