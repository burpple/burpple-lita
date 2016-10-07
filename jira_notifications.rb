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
          room   = Lita::Room.find_by_name(target)
          target = Source.new(room: room)
        end

        body = JSON.load(request.body)

        if body['webhookEvent'] == 'jira:issue_updated' and body['comment']

          body_issue = body['issue']
          issue_key  = body_issue['key']
          issue_summary = body_issue['fields']['summary']
          url = "#{config.jira_url}/browse/#{issue_key}"

          comment      = body['comment']
          content      = comment['body']
          content.scan(/\[~([a-zA-Z0-9]+)\]/).flatten.each do |name|
            user         = Lita::User.fuzzy_find(name)
            mention_name = user ? "@#{user.name}" : "@#{name}"
            content.gsub!(/\[~#{name}\]/, mention_name)
          end
          assignee = nil
          if body_issue and assignee = body_issue['fields']['assignee']
            assignee = assignee['name']
          end

          author_name = comment['author']['name']

          message  = "*#{issue_key} #{issue_summary}* _(#{url})_\n"
          message += "#{author_name} commented:\n"
          content.split("\n").each do |line|
            message += "> #{line}\n"
          end
          message.chomp!
          
          attachment = Lita::Adapters::Slack::Attachment.new("",
            fallback: message,
            color: '#3F51B5',
            pretext: "#{author_name} commented on <#{url}|#{issue_key}>",
            title: issue_summary,
            title_link: url,
            fields: [{
              title: "Comment",
              value: content,
              short: false
            }],
            footer: "cc @#{assignee}"
          )

          robot.chat_service.send_attachment(room, attachment)

        else

          puts "not recognized, webhookEvent=#{body['webhookEvent']}, keys=#{body.keys}"

        end
      end
    end

    Lita.register_handler(JiraNotifications)
  end
end
