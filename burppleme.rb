module Lita
  module Handlers
    class Burppleme < Handler

      config :jwt

      route(/burppleme:?(.+)/) do |r|
        headers = {
          'Authorization' => config.jwt,
          'User-Agent' => 'Burpple Android/5.1',
          'Accept' => 'application/json;version=20170912'
        }
        query = r.matches.join(' ').strip
        uri = URI::HTTPS.build({host: 'app.burpple.com',
                                path: '/p1/search/venues',
                                query: "q=#{CGI.escape(query)}&limit=1",
                              })

        response = HTTParty.get(uri.to_s, headers: headers)

        json_res = JSON.load(response.body)

        venue    = json_res["data"]["venues"].first

        if venue
          venue_url = "https://burpple.com/#{venue["url"]}"
          r.reply "#{venue['name']} #{venue_url}"
        else
          r.reply "Sorry, I couldn't find anything matching #{query}"
        end
      end
    end
    Lita.register_handler(Burppleme)
  end
end
