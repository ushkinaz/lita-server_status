module Lita
  module Handlers
    class ServerStatus < Handler
      MESSAGE_REGEX = /(.+) is starting deploy of '(.+)' from branch '(.+)' to (.+)/i

      route(MESSAGE_REGEX, :save_status)
      route(/server status\s*(.*)/i, :list_statuses, command: true,
            help: {t("command.server_status") => t("help.usage")}
      )

      def save_status(response)
        message                                = response.message.body
        user, application, branch, environment = message.match(MESSAGE_REGEX).captures

        redis.mapped_hmset("#{environment}:#{application}",
                           {
                               :application => application,
                               :environment => environment,
                               :branch      => branch,
                               :user        => user,
                               :time        => formatted_time(Time.now)
                           })
      end

      def list_statuses(response)
        response.reply status_message response.matches[0][0]
      end

      def status_message(env)
        env = "*" if env.empty?
        keys = env + ":*"

        messages = redis.keys(keys).sort.map { |key|
          deployment = redis.mapped_hmget(key, :application, :environment, :branch, :user, :time)

          "#{deployment[:application]} #{deployment[:environment]}: #{deployment[:branch]} (#{deployment[:user]} @ #{deployment[:time]})"
        }
        messages << t("error.no_data") if messages.empty?
        messages.join("\n")
      end

      def formatted_time(time)
        time.strftime("%Y-%m-%d %H:%M")
      end
    end

    Lita.register_handler(ServerStatus)
  end
end
