require "sinatra/base"
require 'json'
require 'rest-client'
require 'searchbing'
require 'dalli'

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
      bing_image = Bing.new(ENV["BING_API_KEY"], 25, 'Image')
      image_url = bing_image.search(msg['content']['text'])[0][:Image].sample[:MediaUrl]
      request_content = {
        to: [msg['content']['from']],
        toChannel: 1383378250,
        eventType: "138311608800106203",
        content: {
          contentType: 2,
          toType: 1,
          originalContentUrl: image_url,
          previewImageUrl: image_url
        }
      }
      send_request(request_content.to_json)
    end
  end
end
