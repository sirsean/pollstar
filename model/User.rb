
=begin

The :username is expected to be unique

The :account_level values are expected to be one of [:free, :cheapo, :standard, :deluxe] and will effect the features the user has access to

=end
class User
    include MongoMapper::Document

    key :username, String, :index => true
    key :email, String
    key :password, String
    key :full_name, String
    key :account_level
    key :monthly_rate, Integer

    def self.username_exists?(username)
        User.all(:username => username).count > 0
    end

    def self.get_by_username(username)
        User.all(:username => username).first
    end

    def self.get_by_username_and_password(username, password)
        User.all(:username => username, :password => password).first
    end

    def self.get_monthly_rate_by_account_level(account_level)
        case account_level
            when :deluxe
                10
            when :standard
                5
            when :cheapo
                2
            when :free
                0
        end
    end

=begin 
How long the user's polls last before they expire and can't be voted on any more.
If this is nil, then the polls will never expire.
This is based on the user's account level.
=end
    def poll_duration
        begin
            if @account_level == :free
                3.months
            else
                nil # any paid account has no expiration date on its polls
            end
        rescue
            3.months #they don't have an account level, so we're calling them a free account
        end
    end

    def max_votes_per_poll
        if @account_level == :deluxe or @account_level == :standard
            return nil
        elsif @account_level == :cheapo
            return 200
        else 
            return 50
        end
    end

    def max_answers_per_poll
        if [:deluxe, :standard, :cheapo].include?(@account_level)
            return nil
        else
            return 3
        end
    end

    def can_copy_own_polls?
        [:deluxe, :standard, :cheapo].include?(@account_level)
    end

    def can_copy_all_polls?
        [:deluxe, :standard].include?(@account_level)
    end

    def can_edit_own_polls?
        [:deluxe, :standard].include?(@account_level)
    end

    def can_choose_chart_type?
        [:deluxe, :standard].include?(@account_level)
    end

    def show_me_ads?
        [:free].include?(@account_level)
    end

    def show_ads_on_my_polls?
        [:free, :cheapo].include?(@account_level)
    end

end

