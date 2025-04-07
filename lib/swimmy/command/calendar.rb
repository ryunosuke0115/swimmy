# coding: utf-8

require 'json'
require 'uri'
require 'net/https'
require 'pp'
require 'date'
require 'fileutils'
require 'active_support/time'

module Swimmy
  module Command
    class Schedule < Swimmy::Command::Base

      command "calendar" do |client, data, match|
        client.say(channel: data.channel, text: "予定を追加中...")

        google_oauth ||= begin
          Swimmy::Service::Schedule.new('config/credentials.json', 'config/tokens.json')
        rescue e
          msg = 'Google OAuthの認証に失敗しました．適切な認証情報が設定されているか確認してください．'
          client.say(channel: data.channel, text: msg)
          return
        end

        if match[:expression]
          arg = match[:expression].split(" ")
          if arg.length != 4
            msg = <<~TEXT
              引数の数が違います
              "swimmy6 calendar <カレンダー名> <イベント名> <開始時間> <終了時間>" のように入力してください
              以下は例です
              "swimmy6 calendar nomlab 第48回開発打ち合わせ 2025-2-26-10:00 2025-2-26-12:00"
            TEXT
          else
            calendarName = arg[0]
            eventName = arg[1]
            startSplitDate = arg[2].split("-")
            finishSplitDate = arg[3].split("-")
            startSplitTime = startSplitDate[3].split(":")
            finishSplitTime = finishSplitDate[3].split(":")
            if startSplitDate.length != 4 || finishSplitDate.length != 4 || startSplitTime.length != 2 || finishSplitTime.length != 2
              msg = <<~TEXT
                  時間の入力形式が違います
                  "2025-2-26-10:00" のように入力してください
              TEXT
            else
              startTime = Time.new(startSplitDate[0], startSplitDate[1], startSplitDate[2], startSplitTime[0], startSplitTime[1], 0)
              finishTime = Time.new(finishSplitDate[0], finishSplitDate[1], finishSplitDate[2], finishSplitTime[0], finishSplitTime[1], 0)

              AddEvents.new(spreadsheet, google_oauth).add_event(calendarName, eventName, startTime, finishTime)

              msg = "#{calendarName}の#{startSplitDate[0]}年#{startSplitDate[1]}月#{startSplitDate[2]}日から#{finishSplitDate[0]}年#{finishSplitDate[1]}月#{finishSplitDate[2]}日にイベント#{eventName}を追加しました"
            end
          end
        else
          msg = <<~TEXT
          引数が入力されていません
          "swimmy6 calendar <カレンダー名> <イベント名> <開始時間> <終了時間>" のように入力してください
          以下は例です
          "swimmy6 calendar nomlab 第48回開発打ち合わせ 2025-2-26-10:00 2025-2-26-12:00"
        TEXT
        end
        client.say(text: msg, channel: data.channel)
      end
    end

    class AddEvents

      require 'sheetq'

      def initialize(spreadsheet, google_oauth)
        @sheet = spreadsheet.sheet("calendar2", Swimmy::Resource::Schedule)
        @google_oauth = google_oauth
      end

      def add_event(calendar_name, summary, startTime, finishTime)
        calendars = @sheet.fetch
        calendar_id = nil
        calendars.each do |calendar|
          if calendar.name == calendar_name
            calendar_id = calendar.id
          end
        end
        puts calendar_id
        event = {
          summary: summary,
          start: {
            dateTime: startTime.iso8601,
            timeZone: 'Asia/Tokyo'
          },
          end: {
            dateTime: finishTime.iso8601,
            timeZone: 'Asia/Tokyo'
          }
        }
        # Google Calendar APIのエンドポイントURL
        uri = URI.parse("https://www.googleapis.com/calendar/v3/calendars/#{calendar_id}/events")

        # HTTPリクエストの作成
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true  # HTTPS通信を使う

        # POSTリクエストを作成
        request = Net::HTTP::Post.new(uri.path, {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{@google_oauth.token}"  # OAuth2トークン
        })
        # イベントデータをJSONとしてリクエストボディにセット
        request.body = event.to_json

        # リクエストを送信してレスポンスを受け取る
        response = http.request(request)

        # レスポンスの処理
        if response.is_a?(Net::HTTPSuccess)
          puts "Event added successfully!"
          # レスポンスボディをJSON形式で解析
          event_response = JSON.parse(response.body)
          puts "Event ID: #{event_response['id']}"
        else
          puts "Failed to add event. Error: #{response.body}"
        end
      end

    end # class Schedule
  end # module Command
end # module Swimmy