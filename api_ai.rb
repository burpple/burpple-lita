require 'uri'
require 'cgi'
require 'httparty'

module Lita
  module Handlers
    class ApiAi < Handler
      http.post "/api_ai/webhook" do |request, res|

        json = request.body.read
        payload = JSON.load(json)

        if result = payload['result']
          params = result['parameters']

          uri = URI::HTTPS.build({host: 'app.burpple.com',
                                  path: '/p1/search',
                                  query: "q=#{CGI.escape(params.values.join(' '))}"})

          response = HTTParty.get(uri.to_s)

          json_res = JSON.load(response.body)
          venues = json_res["data"]["venues"]
        else
          venues = []
        end

        venue = venues.sample
        if venue
          venue_url = "https://burpple.com/#{venue["url"]}"
          response_msg = "How about #{venue["name"]}? #{venue_url}"
          #attachment   = {
          #  title: venue["name"],
          #  title_link: venue_url,
          #}
        else
          venue = {}
          response_msg = "Sorry, I'm a little fuzzy about that."
        end

        response_body = { 
          speech: response_msg,
          displayText: response_msg,
          data: {
            slack: {
              text: response_msg,
              #attachments: [
              #  attachment
              #]
            }
          },
          contextOut:result['contexts'],
          source: "Burpple",
        }

        res.headers["Content-Type"] = "application/json"
        res.write(MultiJson.dump(response_body))
      end
    end
    Lita.register_handler(ApiAi)
  end
end
