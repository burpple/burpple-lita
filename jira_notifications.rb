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
          target = Source.new(room: '#' + target)
        end

        body = JSON.load(request.body)

        puts body.inspect

        if body['webhookEvent'] == 'jira:comment_created' and body['comment']

          body_issue = body['issue']
          issue = "#{body_issue['key']} #{body_issue['fields']['summary']}"
          url = "#{config.jira_url}/browse/#{body_issue['key']}"

          comment = body['comment']
          content = comment['body'].gsub(/\[~([a-zA-Z0-9]+)\]/,'@$1')
          assignee = nil
          if body_issue and assignee = body_issue['fields']['assignee']
            assignee = assignee.name
          end

          message  = "*#{issue}* _(#{url})_\n"
          message += "#{comment['author']['name']} commented:\n"
          message += "> #{content}"
          message += "\ncc @#{assignee}" if assignee

          puts "sending message! target=#{target.inspect} message=#{message}"
          robot.send_message(target, message)

        else

          puts "not recognized, webhookEvent=#{body['webhookEvent']}, keys=#{body.keys}"

        end
      end
    end

    Lita.register_handler(JiraNotifications)
  end
end