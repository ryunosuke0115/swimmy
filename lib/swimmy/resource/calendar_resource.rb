require 'date'
require 'active_support/time'

module Swimmy
  module Resource
    class Schedule

      def leap_year(year)
        return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)
      end

      def is_valid_date(year, month, day)
        nilCount = [year, month, day].count(nil)
        mday = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30]
        # only day
        if nilCount == 2
          return false if day < 1 || day > 31
          return true
        # day/month
        elsif nilCount == 1
          return false if month < 1 || month > 12
          mday[2] = 29
          return false if day < 1 || day > mday[month]
          return true
        # year/month/day
        elsif nilCount == 0
          return false if year < 1 || month < 1 || month > 12 || day < 1
          if month == 2 && leap_year(year)
            mday[2] = 29
          end
          return false if day > mday[month]
          return true
        # invalid
        else
          return false
        end
      end

      def find_nearest_future_date(year, month, day, hour, min, currentTime)
        currentYear = currentTime.year
        currentMonth = currentTime.month
        currentDay = currentTime.day

        case
        when year.nil? && month.nil? && day.nil?
          candidateTime = Time.new(currentYear, currentMonth, currentDay, hour, min, 0)
          if candidateTime < currentTime
            candidateTime += 1.day
          end
        when year.nil? && month.nil? && !day.nil?
          candidateTime = Time.new(currentYear, currentMonth, day, hour, min, 0)
          if candidateTime < currentTime
            candidateTime += 1.month
          end
        when year.nil? && !month.nil? && !day.nil?
          candidateTime = Time.new(currentYear, month, day, hour, min, 0)
          if candidateTime < currentTime
            candidateTime += 1.year
          end
        end

        return candidateTime
      end

      def arg_split(arg)
        help = <<~TEXT
          "swimmy calendar <カレンダー名> <予定名> <開始時間> <終了時間>" のように入力してください
          予定名に空白は使用できません
          以下は例です
          "swimmy6 calendar nomlab 第48回開発打ち合わせ 2025/2/26/10:00 2025/2/26/12:00"
        TEXT
        return [false, nil, "引数の長さが違います\n#{help}"] if arg.length != 4

        currentTime = Time.now
        calendarName = arg[0]
        eventName = arg[1]
        startSplitDate = arg[2].split("/")
        finishSplitDate = arg[3].split("/")

        return [false, nil, "開始時刻と終了時刻の入力形式は統一してください\n#{help}"] if startSplitDate.length != finishSplitDate.length
        dateLength = startSplitDate.length

        return [false, nil, "日付の入力形式が違います\n#{help}"] if dateLength > 4

        startSplitTime = startSplitDate[dateLength - 1].split(":")
        finishSplitTime = finishSplitDate[dateLength - 1].split(":")
        return [false, nil, "時刻の入力形式が違います\n#{help}"] if startSplitTime.length != 2 || finishSplitTime.length != 2

        begin
          case
          when dateLength == 4
            # year/month/day/hour:minute
            raise ArgumentError if !is_valid_date(startSplitDate[0].to_i, startSplitDate[1].to_i, startSplitDate[2].to_i)
            startTime = Time.new(startSplitDate[0].to_i, startSplitDate[1].to_i, startSplitDate[2].to_i, startSplitTime[0], startSplitTime[1], 0)
            finishTime = Time.new(finishSplitDate[0].to_i, finishSplitDate[1].to_i, finishSplitDate[2].to_i, finishSplitTime[0], finishSplitTime[1], 0)
          when dateLength == 3
            # month/day/hour:minute
            raise ArgumentError if !is_valid_date(nil, startSplitDate[0].to_i, startSplitDate[1].to_i)
            startTime = find_nearest_future_date(nil, startSplitDate[0].to_i, startSplitDate[1].to_i, startSplitTime[0].to_i, startSplitTime[1].to_i, currentTime)
            finishTime = find_nearest_future_date(nil, finishSplitDate[0].to_i, finishSplitDate[1].to_i, finishSplitTime[0].to_i, finishSplitTime[1].to_i, startTime)
          when dateLength == 2
            # day/hour:minute
            raise ArgumentError if !is_valid_date(nil, nil, startSplitDate[0].to_i)
            startTime = find_nearest_future_date(nil, nil, startSplitDate[0].to_i, startSplitTime[0].to_i, startSplitTime[1].to_i, currentTime)
            finishTime = find_nearest_future_date(nil, nil, finishSplitDate[0].to_i, finishSplitTime[0].to_i, finishSplitTime[1].to_i, startTime)
          when dateLength == 1
            # hour:minute
            startTime = find_nearest_future_date(nil, nil, nil, startSplitTime[0].to_i, startSplitTime[1].to_i, currentTime)
            finishTime = find_nearest_future_date(nil, nil, nil, finishSplitTime[0].to_i, finishSplitTime[1].to_i, startTime)
          end
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