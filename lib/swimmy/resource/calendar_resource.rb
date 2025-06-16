require 'date'
require 'active_support/time'

module Swimmy
  module Resource
    class InvalidEventTimeError < StandardError; end
    class NotExistDateError < InvalidEventTimeError
      def initialize
        super("不正な時刻形式，または存在しない日付です\n開始または終了時刻に誤りがあるか，無効な時刻が含まれています\n")
      end
    end
    class TimeOrderError < InvalidEventTimeError
      def initialize
        super("開始時刻が終了時刻よりも後，または等しくなっています\n開始時刻は終了時刻よりも前でなければなりません\n")
      end
    end

    class CalendarEvent
      def initialize(event_name, start_time, end_time)
        @event_name = event_name
        @start_time, @end_time = parse(start_time, end_time)
      end

      def self.from_json(event_json)
        event_name = event_json['summary']
        start_time = DateTime.parse(event_json['start']['dateTime'])
        end_time = DateTime.parse(event_json['end']['dateTime'])
        new(event_name, start_time, end_time)
      end

      def name
        @event_name
      end

      def start
        @start_time
      end

      def end
        @end_time
      end

      def to_s
        <<~TEXT
          以下の予定を追加しました

          イベント名: #{@event_name}
          開始: #{@start_time.strftime('%Y年%m月%d日 %H:%M')}
          終了: #{@end_time.strftime('%Y年%m月%d日 %H:%M')}
        TEXT
      end

      private

      DateTimeInfo = Struct.new(:year, :month, :day, :hour, :min)
      def parse(start_time, end_time)
        return start_time, end_time if iso8601_datetime?(start_time) && iso8601_datetime?(end_time)

        start_date_parts, start_time_parts = parse_datetime_parts(start_time)
        end_date_parts, end_time_parts = parse_datetime_parts(end_time)
        date_length = start_date_parts.length

        # check and parse date/time
        begin
          #parse date/time and convert structed data
          start_info = parse_date(start_date_parts, start_time_parts, date_length)
          end_info = parse_date(end_date_parts, end_time_parts, date_length)
          raise ArgumentError unless valid_date?(start_info.year, start_info.month, start_info.day) || valid_date?(end_info.year, end_info.month, end_info.day)
          # complement date/time
          start_time = find_nearest_future_date(
            start_info.year, start_info.month, start_info.day,
            start_info.hour, start_info.min, Time.now
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

        return start_time, end_time
      end

      def iso8601_datetime?(time)
        Time.iso8601(time.to_s)
        true
      rescue ArgumentError
        false
      end

      def parse_datetime_parts(datetime)
        *date_parts, time = datetime.split("/")
        hour, min = time.split(":")
        return date_parts, [hour, min]
      end

      def valid_time_order?(s_time, e_time)
        return s_time < e_time
      end
      def parse_date(date_parts, time_parts, date_length)
        case date_length
        # YYYY/MM/DD/hh:mm
        when 3
          year, month, day = date_parts[0..2].map(&:to_i)
        # MM/DD/hh:mm
        when 2
          year, month, day = [nil] + date_parts[0..1].map(&:to_i)
        # DD/hh:mm
        when 1
          year, month, day = [nil, nil] + [date_parts[0].to_i]
        # hh:mm
        when 0
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
    end # class CalendarEvent
  end # module Resource
end # module Swimmy
