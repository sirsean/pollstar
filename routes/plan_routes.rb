get '/select_plan/?' do
    @cheapo_plan_button = @config["cheapo_plan_button"]
    @standard_plan_button = @config["standard_plan_button"]
    @deluxe_plan_button = @config["deluxe_plan_button"]
    haml :select_plan
end

get '/select_free_plan/?' do
    puts "Selecting free plan"

    puts "#{Time.now}: User #{@current_user.id} switched from #{@current_user.account_level} to free"

    @current_user.account_level = :free
    @current_user.monthly_rate = 0
    @current_user.save

    session["flash"] = "You're on the free plan now"
    redirect_url = (session.delete("redirect_url") or "/home/")
    redirect redirect_url
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
    
    puts "#{Time.now}: User #{@current_user.id} switched from #{@current_user.account_level} to #{account_level}"

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


