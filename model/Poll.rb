
=begin
A MongoDB document representing an individual poll, with a list of its possible answers.

Not all polls will expire -- if the expires_at field is nil, then the poll will never expire. (Polls expire for free users, and not for paying users.)
=end
class Poll
    include MongoMapper::Document

    key :user_id, :index => true
    key :copied_poll_id
    key :question, String
    key :answers, Array
    key :active, Boolean, :index => true
    key :created_at, Time
    key :updated_at, Time
    key :expires_at, Time
    key :max_votes, Integer
    key :chart_type

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

=begin
    Take a list of Vote documents for this poll, and calculate the number of votes for each answer option.
    We do this by looping over the possible answers, and counting the number of votes that match each answer's index.
    Return an array of objects of the form: { "text", "num_votes" } where "text" is the text of the answer option, and "num_votes" is how many times that answer was voted for.
=end
    def calculate_answer_votes(votes)
        @answers.map{ |answer| 
            { "text" => answer["text"], 
                "num_votes" => votes.select{ |vote| 
                    vote["answer_index"] == answer["index"] 
                }.length 
            }
        }
    end

end
