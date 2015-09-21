require 'trello'

module Lita
  module Handlers
    class BurppleTrello < Handler
      config :public_key
      config :token
      config :board

      route(/^report\s+bug\s+[^\s]+/i, :report_bug, 
            restrict_to: [:trello_bugs_admins], command: true,
            help: {
              "report bug <title of bug>" =>
                "Creates a new card in Bug Board's Inbox"
            }
      )

      route(/.*/, :message)

      # route(/^what have you heard/i,
      #       :echo_memory, command: true)

      route(/^clear\s+memory/i, :clear_memory,
            command: true,
            restrict_to: [:trello_bugs_admins])

      def message(r)
        msgs_key = messages_key(r)
        redis.rpush msgs_key, build_msg(r) # store oldest msg at top
        redis.ltrim msgs_key, 0, 49 # keep only last 50 msgs
      end

      def report_bug(r)
        msgs_key = messages_key(r)

        message = r.args[1..-1].join(' ')
        from = r.message.body.scan(/(?<=from )\S+/).first

        last_msg = redis.lindex msgs_key, -1
        start = last_msg == build_msg(r) ? 1 : 0
        history = redis.lrange(msgs_key, start, -1)
        #TODO: smart date limiting

        if from
          begin
            from.sub!(/\A@/,'') # strip @ character
            from = Lita::User.fuzzy_find(from).mention_name
            history.keep_if{ |s| s.sub(/\A.+\] /,'').start_with?(from) }
          rescue
            history = history[0,19]
          end
        else
          history = history[0,19]
        end
        
        description = history.join("\n")

        name = message.sub(/from @\S+/,'')
        r.reply "Ok #{r.user.name}, I'm creating a new card."
        begin
          card = new_card name, description: description
          r.reply "Here you go: #{card.short_url}"
        rescue
          r.reply "Something failed. #{$!}"
        end
      end

      def echo_memory(r)
        r.reply "Here's what I have heard:"
        msgs_key = messages_key(r)

        last_msg = redis.lindex msgs_key, 0
        start = last_msg == build_msg(r) ? 1 : 0

        last_n = r.message.body.scan(/(?<=-n )\d+/).first

        stop = if last_n
                 start == 0 ? last_n.to_i-1 : last_n.to_i
               else
                 -1
               end
        r.reply_privately redis.lrange(msgs_key, start, stop).join("\n")
      end

      def clear_memory(r)
        msgs_key = messages_key(r)
        redis.del msgs_key
        r.reply "Ok, I've forgotten everything in this conversation."
      end

      private
      
      def trello
        @trello ||= ::Trello::Client.new(
          developer_public_key: config.public_key,
          member_token: config.token,
        )
      end

      def bugs_board
        @bugs_board ||= trello.find(:board, config.board)
      end

      def lists
        @lists ||= begin
          bugs_board.lists.map { |list| [list.name.downcase, list] }.to_h
        end
      end

      def inbox_list_id
        if @inbox_list_id.blank? and
            (@inbox_list_id = redis.get 'inbox_list_id').blank?
          @inbox_list_id = lists['inbox'].id
          redis.set 'inbox_list_id', @inbox_list_id
        end
        @inbox_list_id
      end

      def new_card(name, description: nil)
        trello.create(:card,
                      'name' => name,
                      'desc' => description,
                      'idList' => inbox_list_id)
      end

      def messages_key(r)
        source = r.message.source
        room   = source.room || "user_#{source.user.id}"
        "#{room}_messages"
      end

      def build_msg(r)
        time = Time.now.getlocal("+08:00").strftime("%Y-%-m-%-d %I:%M %p")
        "[#{time}] #{r.message.source.user.mention_name}: #{r.message.body}"
      end
    end

    Lita.register_handler(BurppleTrello)
  end
end
