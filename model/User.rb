
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

end

