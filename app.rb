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

  def set_content(to, content)
    {
      to: to,
      toChannel: 1383378250,
      eventType: "138311608800106203",
      content: content
    }
  end

  post '/linebot/callback' do
    params = JSON.parse(request.body.read)

    params['result'].each do |msg|
      to = msg['content']['from']
      case msg['content']['text']
      when /(.+)の画像/
        reply_text = "#{$1}の画像何枚欲しい？\n例) 「3枚」って数字で答えてね!"
        settings.cache.set(to, $1, 600)
        content = {
          contentType: 1,
          toType: 1,
          text: reply_text
        }
        request_content = set_content(to, content)
        send_request(request_content.to_json)
      when /([1-9])枚/
        bing_image = Bing.new(ENV["BING_API_KEY"], 25, 'Image')
        keyword = settings.cache.get(to)
        image_num = $1.to_i
        images = bing_image.search(keyword)[0][:Image].sample(image_num)
        images.each do |image|
          content = {
            contentType: 2,
            toType: 1,
            originalContentUrl: image[:MediaUrl],
            previewImageUrl: image[:MediaUrl]
          }
          request_content = set_content(to, content)
          send_request(request_content.to_json)
        end
        # cache削除
        settings.cache.delete(to)
      else
#        content = {
#          contentType: 8,
#          toType: 1,
#          contentMetadata: {
#            STKID: 3,
#            STKPKGID: 332,
#            STKVER: 100
#          }
#        }
        reply_text = msg['content']['contentMetadata'].to_s
        content = {
          contentType: 1,
          toType: 1,
          text: reply_text
        }
        request_content = set_content(to, content)
        send_request(request_content.to_json)
      end
    end
  end
end
