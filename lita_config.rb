require './burpple_trello.rb'

Dotenv.load

Lita.configure do |config|
  # The name your robot will use.
  config.robot.name = "Lita"

  # The locale code for the language to use.
  # config.robot.locale = :en

  # The severity of messages to log. Options are:
  # :debug, :info, :warn, :error, :fatal
  # Messages at the selected level and above will be logged.
  config.robot.log_level = (ENV["LOG_LEVEL"] || :info).to_sym

  # An array of user IDs that are considered administrators. These users
  # the ability to add and remove other users from authorization groups.
  # What is considered a user ID will change depending on which adapter you use.
  # config.robot.admins = ["1", "2"]
  if admins = ENV["ROBOT_ADMINS"]
    config.robot.admins = admins.split(',')
  end

  # The adapter you want to connect with. Make sure you've added the
  # appropriate gem to the Gemfile.
  # config.robot.adapter = :shell
  # config.adapters.shell.private_chat = true
  config.robot.adapter = :slack
  config.adapters.slack.token = "xoxb-10863559585-QvkE5PfJNyytQv1LIOndQvhj"

  ## Example: Set options for the chosen adapter.
  # config.adapter.username = "myname"
  # config.adapter.password = "secret"

  ## Example: Set options for the Redis connection.
  config.redis[:url] = ENV["REDISCLOUD_URL"]

  ## Use Heroku HTTP port
  config.http.port = ENV["PORT"]

  ## Example: Set configuration for any loaded handlers. See the handler's
  ## documentation for options.
  # config.handlers.some_handler.some_config_key = "value"
  config.handlers.directions.google_api_key = ENV["DIRECTIONS_GOOGLE_API_KEY"]

  # Trello
  config.handlers.burpple_trello.public_key = ENV["TRELLO_PUBLIC_KEY"]
  config.handlers.burpple_trello.token = ENV["TRELLO_TOKEN"]
  config.handlers.burpple_trello.board = ENV["TRELLO_BOARD"]
end
