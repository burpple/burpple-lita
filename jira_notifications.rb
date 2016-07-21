require 'json'

module Lita
  module Handlers
    class JiraNotifications < Handler
      config :jira_url, required: true

      http.post "/jira_webhook/:target" do |request, response|
        target = request.env["router.params"][:target]
        if target.start_with?('@')
          # TODO: is this setup correctly, or does user require Lita::User ?
          target = Source.new(user: target, private_message: true)
        else
          target = Source.new(room: Lita::Room.find_by_name(target))
        end

        body = JSON.load(request.body)

        if body['webhookEvent'] == 'jira:issue_updated' and body['comment']

          body_issue = body['issue']
          issue = "#{body_issue['key']} #{body_issue['fields']['summary']}"
          url = "#{config.jira_url}/browse/#{body_issue['key']}"

          comment      = body['comment']
          content      = comment['body']
          content.scan(/\[~([a-zA-Z0-9]+)\]/).flatten.each do |name|
            user         = Lita::User.fuzzy_find(name)
            mention_name = user ? user.mention_name : name
            content.gsub!(/\[~#{name}\]/,"@#{mention_name}")
          end
          assignee = nil
          if body_issue and assignee = body_issue['fields']['assignee']
            assignee = assignee.name
          end

          message  = "*#{issue}* _(#{url})_\n"
          message += "#{comment['author']['name']} commented:\n"
          message += "> #{content}"
          message += "\ncc @#{assignee}" if assignee

          robot.send_message(target, message)

        else

          puts "not recognized, webhookEvent=#{body['webhookEvent']}, keys=#{body.keys}"

        end
      end
    end

    Lita.register_handler(JiraNotifications)
  end
end
