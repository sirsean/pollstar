
class Poll
    include MongoMapper::Document

    key :user_id
    key :question, String
    key :answers, Array
    key :active, Boolean
    key :created_at, Time
    key :expires_at, Time
    key :max_votes, Integer

    def self.get_by_ids(poll_ids)
        Poll.all(:_id => { "$in" => poll_ids }, :order => 'created_at desc')
    end

    def self.get_by_user_id(user_id)
        Poll.all(:user_id => user_id, :order => 'created_at desc')
    end

    def self.get_latest_by_user_id(user_id, limit)
        Poll.all(:user_id => user_id, :order => "created_at desc", :limit => limit)
    end

    def expired?
        begin
            @expires_at < Time.now
        rescue
            false
        end
    end

end
