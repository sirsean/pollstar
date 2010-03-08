
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

class Log
    include MongoMapper::Document

    key :type
    key :created_at, Time
    key :value, String
    key :user_id
    key :ip, String
    
end

