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

    if @current_user
        @voted = Vote.has_user_voted_on_poll?(@current_user.id, @poll.id)
    else
        @voted = Vote.has_ip_voted_on_poll?(@ip, @poll.id)
        puts "ip: #{@ip}"
        puts "poll_id: #{@poll.id}"
        puts "voted: #{@voted}"
    end
    @votes = Vote.get_by_poll_id(@poll.id)
    @owner = User.find(@poll.user_id)
    @is_owner = (@current_user and (@poll.user_id == @current_user.id))
    @can_copy = (@current_user and ((@is_owner and @current_user.can_copy_own_polls?) or @current_user.can_copy_all_polls?))
    @can_edit = (@current_user and (@is_owner and @current_user.can_edit_own_polls?) and (@votes.count == 0))
    @show_ads = (@show_ads and @owner.show_ads_on_my_polls?)
    puts "Show ads: #{@show_ads}"

    # calculate the number of votes on each answer
    @answer_votes = @poll.calculate_answer_votes(@votes)

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
    puts "Voting on poll: #{poll_id}"
    poll = Poll.find(poll_id)

    def get_redirect(embed, poll_id)
        if not embed
            redirect "/poll/#{poll_id}/"
        else
            redirect "/poll/#{poll_id}/embed/"
        end
    end

    if poll.expired?
        return get_redirect(params["embed"], poll_id)
    end

    votes = Vote.get_by_poll_id(poll.id)
    if poll.max_votes and votes.count >= poll.max_votes
        return get_redirect(params["embed"], poll_id)
    end

    answer_index = params["answer"]

    if @current_user
        user_id = @current_user.id
        user_full_name = @current_user.full_name
        username = @current_user.username
    end

    vote = Vote.create({
        :user_id => user_id,
        :user_full_name => user_full_name,
        :username => username,
        :ip => @ip,
        :poll_id => poll.id,
        :answer_index => answer_index,
    })
    vote.save

    return get_redirect(params["embed"], poll_id)
end


