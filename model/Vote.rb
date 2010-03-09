
=begin
A single vote on a poll.

The user_id is the voter's id, and if it's nil, then it was an anonymous vote.
The username and user_full_name are denormalized values from the voter's User object.
The answer_index corresponds to the index in the Poll's list of answers.
=end
class Vote
    include MongoMapper::Document

    key :user_id, :index => true
    key :poll_id, :index => true
    key :user_full_name, String
    key :username, String
    key :ip, String, :index => true
    key :answer_index, Integer

    def self.has_user_voted_on_poll?(user_id, poll_id)
        Vote.all(:user_id => user_id, :poll_id => poll_id).count > 0
    end

    def self.has_ip_voted_on_poll?(ip, poll_id)
        (Vote.all(:ip => ip, :poll_id => poll_id).count > 0)
    end

    def self.get_by_user_id(user_id)
        Vote.all(:user_id => user_id)
    end

    def self.get_by_poll_id(poll_id)
        Vote.all(:poll_id => poll_id)
    end

end

