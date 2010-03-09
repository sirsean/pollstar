
=begin
The Logger makes it easy to save Log messages, of different logging levels.

It's instantiated with a user_id and IP address (the user_id is nil if nobody is logged in).

It offers convenience methods for logging levels of :debug, :warn, and :error.
=end
class Logger
    def initialize(user_id, ip)
        @user_id = user_id
        @ip = ip
    end

    def log(type, value, user_id, ip)
        log = Log.create({
            :type => type,
            :created_at => Time.now,
            :user_id => user_id,
            :ip => ip,
            :value => value,
        })
        log.save
        puts log.inspect
    end

    def debug(value)
        log(:debug, value, @user_id, @ip)
    end

    def warn(value)
        log(:warn, value, @user_id, @ip)
    end

    def error(value)
        log(:error, value, @user_id, @ip)
    end
end

=begin
A MongoDB object representing an individual log event.

The user_id corresponds to the logged in user, and can be nil.
The IP address is the requesting client's IP.
The type is the logging level.
The value is the string that is being logged.
=end
class Log
    include MongoMapper::Document

    key :type
    key :created_at, Time
    key :value, String
    key :user_id
    key :ip, String
    
end

