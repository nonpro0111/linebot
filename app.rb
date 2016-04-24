require "sinatra/base"
require 'json'
require 'rest-client'
require 'searchbing'
require 'dalli'

class App < Sinatra::Base
  configure do
    dalli = Dalli::Client.new(ENV["MEMCACHIER_SERVERS"].split(","),
                        {:username => ENV["MEMCACHIER_USERNAME"],
                        :password => ENV["MEMCACHIER_PASSWORD"]
                        })
    set :cache, dalli
  end

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

  def request_content(to, content)
    {
      to: to,
      toChannel: 1383378250,
      eventType: "138311608800106203",
      content: content
    }.to_json
  end

  post '/linebot/callback' do
    params = JSON.parse(request.body.read)

    params['result'].each do |msg|
      to = [msg['content']['from']]

      case msg['content']['text']
      when /(.+)の画像/
        reply_text = "#{$1}の画像何枚欲しい？\n例) 「3枚」って数字で答えてね!"
        settings.cache.set(msg['content']['from'], $1, 600)
        content = {
          contentType: 1,
          toType: 1,
          text: reply_text
        }
      when /([1-9])枚/
        keyword = settings.cache.get(msg['content']['from'])
        bing_image = Bing.new(ENV["BING_API_KEY"], 25, 'Image')
        images = bing_image.search(keyword)[0][:Image].sample($1.to_i)
        content = { toType: 1, messages: [] }

        images.each do |image|
          message = { 
            contentType: 2,
            originalContentUrl: image[:MediaUrl],
            previewImageUrl: image[:MediaUrl]
          }
          content[:messages] << message
        end
      else
        content = {
          contentType: 8,
          toType: 1,
          contentMetadata: {
            STKVER: 100,
            STKID: 149,
            STKPKGID: 2
          }
        }
      end

      send_request(request_content(to, content))
    end
  end
end
