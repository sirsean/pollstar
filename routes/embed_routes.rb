get '/poll/:poll_id/embed.js' do |poll_id|
    puts "Embedding poll (javascript): #{poll_id}"
    # remember to set the content-type to javascript
    content_type "text/javascript"
    @poll_id = poll_id
    if @env["rack.request.query_hash"]["width"]
        @width = @env["rack.request.query_hash"]["width"].to_i
    else
        @width = 570
    end
    if @env["rack.request.query_hash"]["height"]
        @height = @env["rack.request.query_hash"]["height"].to_i
    else
        @height = 520
    end
    puts "width: #{@width}, height: #{@height}"
    haml :embed_js, :layout => false
end

get '/poll/:poll_id/embed/' do |poll_id|
    puts "Embedding poll: #{poll_id}"
    if @env["rack.request.query_hash"]["width"]
        @width = @env["rack.request.query_hash"]["width"].to_i
    else
        @width = 570
    end
    if @env["rack.request.query_hash"]["height"]
        @height = @env["rack.request.query_hash"]["height"].to_i
    else
        @height = 520
    end
    puts "width: #{@width}, height: #{@height}"
    @poll = Poll.find(poll_id)
    if @current_user
        @voted = Vote.has_user_voted_on_poll?(@current_user.id, @poll.id)
        puts "logged in user voted: #{@voted}"
    else
        @voted = Vote.has_ip_voted_on_poll?(@ip, @poll.id)
        puts "anonymous user voted: #{@voted}"
    end
    @votes = Vote.get_by_poll_id(@poll.id)

    # calculate the number of votes on each answer
    @answer_votes = @poll.calculate_answer_votes(@votes)

    haml :embed, :layout => false
end


