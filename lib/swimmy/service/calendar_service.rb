# coding: utf-8

require 'sheetq'
require 'json'
require 'uri'
require 'net/https'

module Swimmy
  module Service
    class Schedule
      def initialize(spreadsheet, google_oauth)
        @sheet = spreadsheet.sheet("calendar2", Swimmy::Resource::Calendar)
        @google_oauth = google_oauth
      end

      def add_event(eventInfo)
        calendarName = eventInfo[:calendarName]
        eventName = eventInfo[:eventName]
        startTime = eventInfo[:startTime]
        finishTime = eventInfo[:finishTime]
        calendars = @sheet.fetch
        calendarId = nil
        calendars.each do |calendar|
          if calendar.name == calendarName
            calendarId = calendar.id
          end
        end
        if calendarId.nil?
          return "#{calendarName}というカレンダーが見つかりませんでした\nカレンダー名が正しいかどうか確認してください\n"
        end

        event = {
          summary: eventName,
          start: {
            dateTime: startTime.iso8601,
            timeZone: 'Asia/Tokyo'
          },
          end: {
            dateTime: finishTime.iso8601,
            timeZone: 'Asia/Tokyo'
          }
        }
        # Google Calendar API Endpoint URL
        uri = URI.parse("https://www.googleapis.com/calendar/v3/calendars/#{calendarId}/events")

        # make HTTP request
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true  # HTTPS

        # POST request
        request = Net::HTTP::Post.new(uri.path, {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{@google_oauth.token}"  # OAuth2.0 token
        })
        # set event data
        request.body = event.to_json

        # send request
        response = http.request(request)

        # check response
        if response.is_a?(Net::HTTPSuccess)
          eventData = JSON.parse(response.body)
          createdTime = Time.parse(eventData['created']).getlocal

          msg = <<~TEXT
            #{calendarName}に以下の予定を追加しました

            イベント名: #{eventName}
            開始: #{startTime.year}年#{startTime.month}月#{startTime.day}日#{startTime.hour}:#{startTime.min.to_s.rjust(2, '0')}
            終了: #{finishTime.year}年#{finishTime.month}月#{finishTime.day}日#{finishTime.hour}:#{finishTime.min.to_s.rjust(2, '0')}
            作成: #{createdTime.year}年#{createdTime.month}月#{createdTime.day}日#{createdTime.hour}:#{createdTime.min.to_s.rjust(2, '0')}
          TEXT

          return msg
        else
          return "Failed to add event. Error: #{response.body}"
        end
      end
    end # class Schedule
  end # module Service
end # module Swimmy