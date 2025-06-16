module Swimmy
  module Command
    class Schedule < Swimmy::Command::Base
      command "calendar" do |client, data, match|
        google_oauth ||= begin
          Swimmy::Resource::GoogleOAuth.new('config/credentials.json', 'config/tokens.json')
        rescue => e
          msg = 'Google OAuthの認証に失敗しました．適切な認証情報が設定されているか確認してください．'
          client.say(channel: data.channel, text: msg)
          return
        end

        if match[:expression]
          client.say(channel: data.channel, text: "予定を追加中...")
          arg = match[:expression].split(" ")
          msg = begin
            (calendar_name, event_name, start_time, end_time) = CalendarArgsParser.new.parse(arg)
            calendar_service = Swimmy::Service::GoogleCalendar.from_spreadsheet(google_oauth, spreadsheet, calendar_name)
            event = Swimmy::Resource::CalendarEvent.new(event_name, start_time, end_time)
            added_event = calendar_service.add_event(event)
            added_event.to_s
          rescue CommandError, Swimmy::Service::GoogleCalendarError, Swimmy::Resource::InvalidEventTimeError => e
            e.message
          end
        else
          # no arguments
          # help message
          msg = <<~TEXT
            calendar <カレンダー名> <予定名> <開始時刻> <終了時刻> - 指定されたカレンダーに予定を追加します
            予定名に空白は使用できません
            開始・終了時刻の形式は以下のいずれかであり，省略された要素は自動で補完されます
            1. 時間のみ - 例: "10:00"
            2. 日/時間 - 例: "18/10:00"
            3. 月/日/時間 - 例: "4/18/10:00"
            4. 年/月/日/時間 - 例: "2023/4/18/10:00"
          TEXT
        end
        client.say(text: msg, channel: data.channel)
      end
    end # class Schedule

    private

    class CommandError < StandardError; end
    class ArgumentLengthError < CommandError
      def initialize
        super("引数の長さが違います\n")
      end
    end
    class DateFormatError < CommandError
      def initialize
        super("開始時刻と終了時刻の形式が統一されていないか，日付の形式が不正です\n")
      end
    end
    class TimeFormatError < CommandError
      def initialize
        super("時間の入力形式が不正です\n")
      end
    end

    class CalendarArgsParser
      def parse(arg)
        # check argument length
        raise ArgumentLengthError unless valid_argument_length?(arg)

        calendar_name = arg[0]
        event_name = arg[1]
        start_date_parts = arg[2].split("/")
        end_date_parts = arg[3].split("/")

        # check date format
        raise DateFormatError unless valid_date_format?(start_date_parts, end_date_parts)

        date_length = start_date_parts.length
        start_time_parts = start_date_parts[date_length - 1].split(":")
        end_time_parts = end_date_parts[date_length - 1].split(":")

        # check time format
        raise TimeFormatError unless valid_time_format?(start_time_parts, end_time_parts)
        return arg
      end

      def valid_argument_length?(arg)
        return arg.length == 4
      end

      def valid_date_format?(s_date, e_date)
        return s_date.length == e_date.length || s_date.length > 4 || e_date.length > 4
      end

      def valid_time_format?(s_time, e_time)
        return s_time.length == 2 && e_time.length == 2
      end
    end # class CalendarArgsParser
  end # module Command
end # module Swimmy
