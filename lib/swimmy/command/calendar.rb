# coding: utf-8

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
            (calendar_name, event_name, start_time, end_time) = CalendarArgsParser.new(Time.new).parse(arg)
            calendar_service = Swimmy::Service::GoogleCalendar.from_spreadsheet(google_oauth, spreadsheet, calendar_name)
            added_event = calendar_service.add_event(event_name, start_time, end_time)
            added_event.to_s
          rescue CommandError, Swimmy::Service::GoogleCalendarError => e
            e.message
          end
        else
          # no arguments
          # help message
          msg = <<~TEXT
            calendar <カレンダー名> <予定名> <開始時刻> <終了時刻> - 指定されたカレンダーに予定を追加します
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

    CALENDAR_ERROR = <<~TEXT
      "swimmy calendar <カレンダー名> <予定名> <開始時刻> <終了時刻>" のように入力してください
      予定名に空白は使用できません
      また，時間のみ・日/時間・月/日/時間の入力の際は省略要素が自動で補完されます
      以下は入力例です
      "swimmy calendar nomlab 第48回開発打ち合わせ 4/18/10:00 4/18/12:00"
    TEXT

    class CommandError < StandardError; end
    class ArgumentLengthError < CommandError
      def initialize
        super("引数の長さが違います\n#{CALENDAR_ERROR}")
      end
    end
    class DateFormatError < CommandError
      def initialize
        super("開始時刻と終了時刻の形式が統一されていないか，日付の形式が不正です\n#{CALENDAR_ERROR}")
      end
    end
    class TimeFormatError < CommandError
      def initialize
        super("時間の入力形式が不正です\n#{CALENDAR_ERROR}")
      end
    end
    class NotExistDateError < CommandError
      def initialize
        super("不正な時刻形式，または存在しない日付です\n開始または終了時刻に誤りがあるか，無効な時刻が含まれています\n#{CALENDAR_ERROR}")
      end
    end
    class TimeOrderError < CommandError
      def initialize
        super("開始時刻が終了時刻よりも後，または等しくなっています\n開始時刻は終了時刻よりも前でなければなりません\n#{CALENDAR_ERROR}")
      end
    end

    class CalendarArgsParser
      DateTimeInfo = Struct.new(:year, :month, :day, :hour, :min)

      def initialize(time)
        @current_time = time
      end

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

        # check and parse date/time
        begin
          #parse date/time and convert structed data
          start_info = parse_date(start_date_parts, start_time_parts, date_length)
          end_info = parse_date(end_date_parts, end_time_parts, date_length)
          raise ArgumentError unless valid_date?(start_info.year, start_info.month, start_info.day) || valid_date?(end_info.year, end_info.month, end_info.day)
          # complement date/time
          start_time = find_nearest_future_date(
            start_info.year, start_info.month, start_info.day,
            start_info.hour, start_info.min, @current_time
          )
          end_time = find_nearest_future_date(
            end_info.year, end_info.month, end_info.day,
            end_info.hour, end_info.min, start_time
          )
        rescue => e
          raise NotExistDateError
        end

        # check start time before end time
        raise TimeOrderError unless valid_time_order?(start_time, end_time)
        return calendar_name, event_name, start_time, end_time
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

      def valid_time_order?(s_time, e_time)
        return s_time < e_time
      end

      def parse_date(date_parts, time_parts, date_length)
        case date_length
        # YYYY/MM/DD/hh:mm
        when 4
          year, month, day = date_parts[0..2].map(&:to_i)
        # MM/DD/hh:mm
        when 3
          year, month, day = [nil] + date_parts[0..1].map(&:to_i)
        # DD/hh:mm
        when 2
          year, month, day = [nil, nil] + [date_parts[0].to_i]
        # hh:mm
        when 1
          year, month, day = [nil, nil, nil]
        end
        hour, min = time_parts[0..1].map(&:to_i)
        return DateTimeInfo.new(year, month, day, hour, min)
      end

      def leap_year?(year)
        return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)
      end

      def valid_date?(year, month, day)
        mday = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

        case date_type(year, month, day)
        # YYYY/MM/DD/hh:mm
        when :full_date
          return false if year < 1 || month < 1 || month > 12 || day < 1
          if month == 2 && leap_year?(year)
            mday[2] = 29
          end
          return day <= mday[month]
        # MM/DD/hh:mm
        when :month_day_time
          return false if month < 1 || month > 12
          mday[2] = 29
          return day >= 1 && day <= mday[month]
        # DD/hh:mm
        when :day_time
          return day >= 1 && day <= 31
        # hh:mm
        when :time_only
          return true
        # invalid
        else
          return false
        end
      end

      def find_nearest_future_date(year, month, day, hour, min, base_time)
        case date_type(year, month, day)
        # YYYY/MM/DD/hh:mm
        when :full_date
          return Time.new(year, month, day, hour, min, 0)
        # MM/DD/hh:mm
        when :month_day_time
          candidate_time = Time.new(base_time.year, month, day, hour, min, 0)
          return candidate_time if candidate_time > base_time
          search_year = base_time.year
          until valid_date?(search_year += 1, month, day)
            next
          end
          return Time.new(search_year, month, day, hour, min, 0)
        # DD/hh:mm
        when :day_time
          search_year, search_month = find_next_valid_date(base_time.year, base_time.month, day)
          candidate_time = Time.new(search_year, search_month, day, hour, min, 0)
          return candidate_time if candidate_time > base_time
          search_year, search_month = find_next_valid_date(search_year, search_month + 1, day)
          return Time.new(search_year, search_month, day, hour, min, 0)
        #hh:mm
        when :time_only
          candidate_time = Time.new(base_time.year, base_time.month, base_time.day, hour, min, 0)
          return candidate_time + 1.day if candidate_time < base_time
          return candidate_time
        # invalid
        else
          return nil
        end
      end

      def find_next_valid_date(year, month, day)
        until valid_date?(year, month, day)
          month += 1
          if month > 12
            year += 1
            month = 1
          end
        end
        return year, month
      end

      def date_type(year, month, day)
        case [year, month, day].count(nil)
        when 3 then :time_only
        when 2 then :day_time
        when 1 then :month_day_time
        when 0 then :full_date
        else nil
        end
      end
    end # class CalendarArgsParser
  end # module Command
end # module Swimmy
