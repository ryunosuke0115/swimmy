require 'date'
require 'active_support/time'

module Swimmy
  module Resource
    class Schedule
      def arg_split(arg)
        help = <<~TEXT
          "swimmy6 calendar <カレンダー名> <予定名> <開始時間> <終了時間>" のように入力してください
          予定名に空白は使用できません
          以下は例です
          "swimmy6 calendar nomlab 第48回開発打ち合わせ 2025/2/26/10:00 2025/2/26/12:00"
        TEXT
        return [false, nil, "引数の長さが違います\n#{help}"] if arg.length != 4

        calendarName = arg[0]
        eventName = arg[1]
        startSplitDate = arg[2].split("/")
        finishSplitDate = arg[3].split("/")
        return [false, nil, "日付の入力形式が違います\n#{help}"] if startSplitDate.length != 4 || finishSplitDate.length != 4

        startSplitTime = startSplitDate[3].split(":")
        finishSplitTime = finishSplitDate[3].split(":")
        return [false, nil, "時刻の入力形式が違います\n#{help}"] if startSplitTime.length != 2 || finishSplitTime.length != 2

        begin
          startYear, startMonth, startDay = startSplitDate[0..2].map(&:to_i)
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
      end
    end # class Schedule
  end # module Resource
end # module Swimmy