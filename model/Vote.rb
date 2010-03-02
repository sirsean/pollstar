
class Vote
    include MongoMapper::Document

    key :user_id
    key :poll_id
    key :user_full_name, String
    key :username, String
    key :answer_index, Integer

    def self.has_user_voted_on_poll(user_id, poll_id)
        Vote.all(:user_id => user_id, :poll_id => poll_id).count > 0
    end

    def self.get_by_user_id(user_id)
        Vote.all(:user_id => user_id)
    end

    def self.get_by_poll_id(poll_id)
        Vote.all(:poll_id => poll_id)
    end

end

