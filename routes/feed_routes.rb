get '/user/:username/polls/feed/?' do |username|
    puts "Getting user polls feed: #{username}"
    @user = User.get_by_username(username)
    @polls = Poll.get_by_user_id(@user.id)

    builder do |xml|
        xml.instruct! :xml, :version => '1.0'
        xml.rss :version => "2.0" do
            xml.channel do
                xml.title "[#{@site_name}] #{@user.username}"
                xml.description "polls by #{@user.full_name}"
                xml.link "http://#{@site_hostname}/user/#{@user.username}/"

                @polls.each do |poll|
                    xml.item do
                        xml.title poll.question
                        xml.link "http://#{@site_hostname}/poll/#{poll.id}/"
                        xml.pubDate Time.parse(poll.created_at.to_s).rfc822()
                        xml.guid "http://#{@site_hostname}/poll/#{poll.id}/"
                    end
                end
            end
        end
    end
end

