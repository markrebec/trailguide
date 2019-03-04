module TrailGuide
  class Unity
    NAMESPACE = :unity

    def self.clear!
      keys = TrailGuide.redis.keys("#{NAMESPACE}:*")
      TrailGuide.redis.del *keys unless keys.empty?
    end

    attr_reader :visitor_id, :user_id

    def initialize(user_id: nil, visitor_id: nil)
      @user_id = user_id.to_s if user_id.present?
      @visitor_id = visitor_id.to_s if visitor_id.present?
    end

    def user_id=(uid)
      @user_id = uid.to_s
    end

    def visitor_id=(vid)
      @visitor_id = vid.to_s
    end

    def stored_user_id
      TrailGuide.redis.get(visitor_key) if visitor_id.present?
    end

    def stored_visitor_id
      TrailGuide.redis.get(user_key) if user_id.present?
    end

    def valid?
      visitor_id.present? && user_id.present?
    end

    def stored?
      stored_visitor_id.present? && stored_user_id.present?
    end

    def synced?
      valid? && stored? && 
        stored_visitor_id == visitor_id &&
        stored_user_id == user_id
    end

    def sync!
      @user_id ||= stored_user_id
      @visitor_id ||= stored_visitor_id
      delete!
      save!
    end

    def save!
      return false unless valid?
      TrailGuide.redis.set(user_key, visitor_id)
      TrailGuide.redis.set(visitor_key, user_id)
    end

    def delete!
      keys = []
      keys << stored_user_key if stored_user_id.present?
      keys << stored_visitor_key if stored_visitor_id.present?
      keys << user_key if user_id.present?
      keys << visitor_key if visitor_id.present?
      TrailGuide.redis.del(*keys) unless keys.empty?
    end

    protected

    def user_key
      "#{NAMESPACE}:uids:#{user_id}"
    end

    def visitor_key
      "#{NAMESPACE}:vids:#{visitor_id}"
    end

    def stored_user_key
      "#{NAMESPACE}:uids:#{stored_user_id}"
    end

    def stored_visitor_key
      "#{NAMESPACE}:vids:#{stored_visitor_id}"
    end
  end
end
