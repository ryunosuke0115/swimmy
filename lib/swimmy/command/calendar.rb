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
          Swimmy::Resource::GoogleOAuth.new('config/credentials.json', 'config/tokens.json')
        rescue => e
          msg = 'Google OAuthの認証に失敗しました．適切な認証情報が設定されているか確認してください．'
          client.say(channel: data.channel, text: msg)
          return
        end

        if match[:expression]
          arg = match[:expression].split(" ")
          is_valid_arg, eventInfo, msg = Schedule.new.arg_split(arg)
          if is_valid_arg
            msg = AddEvents.new(spreadsheet, google_oauth).add_event(eventInfo)
          end
        else
          msg = "引数が入力されていません"
        end
        client.say(text: msg, channel: data.channel)
      end

      def arg_split(arg)
        help = <<~TEXT
          "swimmy6 calendar <カレンダー名> <イベント名> <開始時間> <終了時間>" のように入力してください
          イベント名に空白は使用できません
          以下は例です
          "swimmy6 calendar nomlab 第48回開発打ち合わせ 2025-2-26-10:00 2025-2-26-12:00"
        TEXT
        if arg.length == 4
          calendarName = arg[0]
          eventName = arg[1]
          startSplitDate = arg[2].split("/")
          finishSplitDate = arg[3].split("/")
          startSplitTime = startSplitDate[3].split(":")
          finishSplitTime = finishSplitDate[3].split(":")
          if startSplitDate.length == 4 && finishSplitDate.length == 4 && startSplitTime.length == 2 && finishSplitTime.length == 2
            begin
              startYear ,startMonth, startDay = startSplitDate[0..2].map(&:to_i)
              finishYear, finishMonth, finishDay = finishSplitDate[0..2].map(&:to_i)
              [startYear, startMonth, startDay, finishYear, finishMonth, finishDay].each do |i|
                raise ArgumentError if i.negative?
              end
              startDate = Date.new(startYear, startMonth, startDay)
              finishDate = Date.new(finishYear, finishMonth, finishDay)
              startTime = Time.new(startDate.year, startDate.month, startDate.day, startSplitTime[0], startSplitTime[1], 0)
              finishTime = Time.new(finishDate.year, finishDate.month, finishDate.day, finishSplitTime[0], finishSplitTime[1], 0)
            rescue => e
              msg = <<~TEXT
                不正な時刻形式，または存在しない日付です
                開始または終了時刻に誤りがあるか，無効な時刻が含まれています
              TEXT
              return false, nil, msg
            end
            begin
              raise ArgumentError if startTime >= finishTime
            rescue => e
              msg = <<~TEXT
                開始時刻が終了時刻よりも後，または等しくなっています
                開始時刻は終了時刻よりも前でなければなりません
                入力された時刻:
                  開始: #{startTime.year}年#{startTime.month}月#{startTime.day}日#{startTime.hour}:#{startTime.min.to_s.rjust(2, '0')}
                  終了: #{finishTime.year}年#{finishTime.month}月#{finishTime.day}日#{finishTime.hour}:#{finishTime.min.to_s.rjust(2, '0')}
              TEXT
              return false, nil, msg
            end
            eventInfo = {
              calendarName: calendarName,
              eventName: eventName,
              startTime: startTime,
              finishTime: finishTime
            }
            return true, eventInfo, nil
          else
            msg = "時刻の入力形式が違います\n"
            return false, nil, msg + help
          end
        else
          msg = "引数の長さが違います\n"
          return false, nil, msg + help
        end
      end
    end

    class AddEvents

      require 'sheetq'

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
        # Google Calendar APIのURL
        uri = URI.parse("https://www.googleapis.com/calendar/v3/calendars/#{calendarId}/events")

        # HTTPリクエストの作成
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true  # HTTPS通信

        # POSTリクエスト
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
          return "#{calendarName}の#{startTime.year}年#{startTime.month}月#{startTime.day}日#{startTime.hour}:#{startTime.min.to_s.rjust(2, '0')}から#{finishTime.year}年#{finishTime.month}月#{finishTime.day}日#{finishTime.hour}:#{finishTime.min.to_s.rjust(2, '0')}にイベント#{eventName}を追加しました"
        else
          return "Failed to add event. Error: #{response.body}"
        end
      end

    end # class Schedule
  end # module Command
end # module Swimmy