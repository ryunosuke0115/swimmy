require 'date'
require 'active_support/time'

module Swimmy
  module Resource
    class CalendarEvent
      def initialize(event_name, start_time, end_time)
        @event_name = event_name
        @start_time = start_time
        @end_time = end_time
      end

      def self.from_json(event_json)
        event_name = event_json['summary']
        start_time = DateTime.parse(event_json['start']['dateTime'])
        end_time = DateTime.parse(event_json['end']['dateTime'])
        new(event_name, start_time, end_time)
      end

      def to_s
        <<~TEXT
          以下の予定を追加しました

          イベント名: #{@event_name}
          開始: #{@start_time.strftime('%Y年%m月%d日 %H:%M')}
          終了: #{@end_time.strftime('%Y年%m月%d日 %H:%M')}
        TEXT
      end
    end # class CalendarEvent
  end # module Resource
end # module Swimmy
