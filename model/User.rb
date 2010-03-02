
class User
    include MongoMapper::Document

    key :username, String
    key :email, String
    key :password, String
    key :full_name, String

    def self.username_exists?(username)
        User.all(:username => username).count > 0
    end

    def self.get_by_username(username)
        User.all(:username => username).first
    end

    def self.get_by_username_and_password(username, password)
        User.all(:username => username, :password => password).first
    end

=begin 
How long the user's polls last before they expire and can't be voted on any more.
If this is nil, then the polls will never expire.
This is based on the user's account level.
=end
    def poll_duration
        3.months
    end

end

