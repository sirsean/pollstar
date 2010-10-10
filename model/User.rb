
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

Polls no longer expire
=end
    def poll_duration
        nil
    end

=begin
Removed different plan levels; all polls have unlimited votes
=end
    def max_votes_per_poll
        nil
    end

=begin
Removed different plan levels; all polls have unlimited answers
=end
    def max_answers_per_poll
        nil
    end

    def can_copy_own_polls?
        true
    end

    def can_copy_all_polls?
        true
    end

    def can_edit_own_polls?
        true
    end

    def can_choose_chart_type?
        true
    end

    def show_me_ads?
        true
    end

    def show_ads_on_my_polls?
        true
    end

    def can_embed_my_polls?
        true
    end

end

