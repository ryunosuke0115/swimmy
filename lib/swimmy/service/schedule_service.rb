require 'sheetq'
require 'json'
require 'uri'
require 'net/https'

module Swimmy
  module Service
    class GoogleCalendarError < StandardError; end
    class CalendarNotFoundError < GoogleCalendarError
      def initialize(calendar_name)
        super("#{calendar_name}というカレンダーが見つかりませんでした\nカレンダー名が正しいかどうか確認してください\n")
      end
    end

    class GoogleCalendarAPIError < GoogleCalendarError
      def initialize(response)
        super("Google Calendar APIの呼び出しに失敗しました: #{response.code} #{response.message}\nAPIの設定や認証情報を確認してください")
      end
    end

    class GoogleCalendar
      def initialize(calendar_id, google_oauth)
        @calendar_id = calendar_id
        @google_oauth = google_oauth
      end

      def self.from_spreadsheet(google_oauth, spreadsheet, calendar_name)
        calendars = spreadsheet.sheet("calendar", Swimmy::Resource::Calendar).fetch
        calendar_id = nil
        calendars.each do |calendar|
          if calendar.name == calendar_name
            calendar_id = calendar.id
          end
        end
        if calendar_id.nil?
          raise CalendarNotFoundError.new(calendar_name)
        end
        new(calendar_id, google_oauth)
      end

      def add_event(event)
        # make event data
        event_info = {
          summary: event.name,
          start: {
            dateTime: event.start.iso8601,
            timeZone: 'Asia/Tokyo'
          },
          end: {
            dateTime: event.end.iso8601,
            timeZone: 'Asia/Tokyo'
          }
        }

        # Google Calendar API Endpoint URL
        uri = URI.parse("https://www.googleapis.com/calendar/v3/calendars/#{@calendar_id}/events")

        # make HTTP request
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true  # HTTPS

        # POST request
        request = Net::HTTP::Post.new(uri.path, {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{@google_oauth.token}"  # OAuth2.0 token
        })

        # set event data
        request.body = event_info.to_json

        # send request
        response = http.request(request)

        # check response
        if response.is_a?(Net::HTTPSuccess)
          return Swimmy::Resource::CalendarEvent.from_json(JSON.parse(response.body))
        else
          raise GoogleCalendarAPIError.new(response)
        end
      end
    end # class Schedule
  end # module Service
end # module Swimmy
