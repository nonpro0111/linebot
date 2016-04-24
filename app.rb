require "sinatra/base"
require 'json'
require 'rest-client'
require 'searchbing'
require 'memcachier'
require 'dalli'
ENV["MEMCACHIER_SERVERS"] = "mc3.dev.ec2.memcachier.com:11211"

configure do
  dalli = Dalli::Client.new(ENV["MEMCACHIER_SERVERS"].split(","),
                      {:username => ENV["MEMCACHIER_USERNAME"],
                      :password => ENV["MEMCACHIER_PASSWORD"]
                      })
  set :cache, dalli
end

class App < Sinatra::Base
  def send_request(content_json)
    endpoint_uri = 'https://trialbot-api.line.me/v1/events'
    RestClient.proxy = ENV['FIXIE_URL'] if ENV['FIXIE_URL']
    RestClient.post(endpoint_uri, content_json, {
      'Content-Type' => 'application/json; charset=UTF-8',
      'X-Line-ChannelID' => ENV["LINE_CHANNEL_ID"],
      'X-Line-ChannelSecret' => ENV["LINE_CHANNEL_SECRET"],
      'X-Line-Trusted-User-With-ACL' => ENV["LINE_CHANNEL_MID"],
    })
  end

  post '/linebot/callback' do
    params = JSON.parse(request.body.read)

    params['result'].each do |msg|
      message = msg['content']['text']
      if message.match(/(.+)の画像/)
        reply_text = "#{message[1]}の画像何枚欲しい？\n例) 「3枚」とか「3」って数字で答えてね!"
        settings.cache.set("#{msg['content']['from']}:target", message[1], 600)
      else
        reply_text = "え？だれの画像？"
      end

#      bing_image = Bing.new(ENV["BING_API_KEY"], 25, 'Image')
#      image_url = bing_image.search(msg['content']['text'])[0][:Image].sample[:MediaUrl]

      request_content = {
        to: [msg['content']['from']],
        toChannel: 1383378250,
        eventType: "138311608800106203",
        content: {
          contentType: 1,
          toType: 1,
          text: settings.cache.get("#{msg['content']['from']}:target")
        }
      }
#      request_content = {
#        to: [msg['content']['from']],
#        toChannel: 1383378250,
#        eventType: "138311608800106203",
#        content: {
#          contentType: 2,
#          toType: 1,
#          originalContentUrl: image_url,
#          previewImageUrl: image_url
#        }
#      }
      send_request(request_content.to_json)
    end
  end
end
