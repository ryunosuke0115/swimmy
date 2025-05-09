require 'date'
require 'active_support/time'

module Swimmy
  module Resource
    class Schedule

      def is_leap_year(year)
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
          if month == 2 && is_leap_year(year)
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
          if candidateTime < currentTime || !is_valid_date(currentYear, currentMonth, day)
            searchYear = currentYear
            searchMonth = currentMonth
            while 1
              searchMonth += 1
              if searchMonth > 12
                searchYear += 1
                searchMonth = 1
              end
              if is_valid_date(searchYear, searchMonth, day)
                candidateTime = Time.new(searchYear, searchMonth, day, hour, min, 0)
                break
              end
            end
          end

        when year.nil? && !month.nil? && !day.nil?
          candidateTime = Time.new(currentYear, month, day, hour, min, 0)
          if candidateTime < currentTime
            searchYear = currentYear
            searchYear += 1
            while !is_valid_date(searchYear, month, day)
              searchYear += 1
            end
            candidateTime = Time.new(searchYear, month, day, hour, min, 0)
          end
        end

        return candidateTime
      end

      def arg_split(arg)
        error = <<~TEXT
          "swimmy calendar <カレンダー名> <予定名> <開始時刻> <終了時刻>" のように入力してください
          予定名に空白は使用できません
          また，時刻のみ・日/時刻・月/日/時刻の入力の際は省略要素が自動で補完されます
          以下は入力例です
          "swimmy calendar nomlab 第48回開発打ち合わせ 4/18/10:00 4/18/12:00"
        TEXT

        begin
          raise ArgumentError if arg.nil?
        rescue => e
          msg = <<~TEXT
            calendar <カレンダー名> <予定名> <開始時刻> <終了時刻> - 指定されたカレンダーに予定を追加します
            開始・終了時刻の形式は以下のいずれかであり，統一される必要があります
            1. 時刻のみ - 例: "10:00"
            2. 日/時刻 - 例: "18/10:00"
            3. 月/日/時刻 - 例: "4/18/10:00"
            4. 年/月/日/時刻 - 例: "2023/4/18/10:00"
          TEXT
          return [false, nil, msg]
        end

        begin
          raise ArgumentError if arg.length > 4
        rescue => e
          msg = <<~TEXT
            引数の数が違います
            #{error}
          TEXT
          return [false, nil, msg]
        end

        currentTime = Time.now
        calendarName = arg[0]
        eventName = arg[1]
        startSplitDate = arg[2].split("/")
        finishSplitDate = arg[3].split("/")

        begin
          raise ArgumentError if startSplitDate.length != finishSplitDate.length
        rescue => e
          msg = <<~TEXT
            開始時刻と終了時刻の入力形式が統一されていません
            #{error}
          TEXT
          return [false, nil, msg]
        end
        dateLength = startSplitDate.length

        begin
          raise ArgumentError if dateLength > 4

          startSplitTime = startSplitDate[dateLength - 1].split(":")
          finishSplitTime = finishSplitDate[dateLength - 1].split(":")
          raise ArgumentError if startSplitTime.length != 2 || finishSplitTime.length != 2
        rescue => e
          msg = <<~TEXT
            日付，または時刻の形式が不正です
            #{error}
          TEXT
          return [false, nil, msg]
        end

        begin
          case dateLength
          when 4
            # year/month/day/hour:minute
            raise ArgumentError if !is_valid_date(startSplitDate[0].to_i, startSplitDate[1].to_i, startSplitDate[2].to_i)
            startTime = Time.new(startSplitDate[0].to_i, startSplitDate[1].to_i, startSplitDate[2].to_i, startSplitTime[0], startSplitTime[1], 0)
            finishTime = Time.new(finishSplitDate[0].to_i, finishSplitDate[1].to_i, finishSplitDate[2].to_i, finishSplitTime[0], finishSplitTime[1], 0)
          when 3
            # month/day/hour:minute
            raise ArgumentError if !is_valid_date(nil, startSplitDate[0].to_i, startSplitDate[1].to_i)
            startTime = find_nearest_future_date(nil, startSplitDate[0].to_i, startSplitDate[1].to_i, startSplitTime[0].to_i, startSplitTime[1].to_i, currentTime)
            finishTime = find_nearest_future_date(nil, finishSplitDate[0].to_i, finishSplitDate[1].to_i, finishSplitTime[0].to_i, finishSplitTime[1].to_i, startTime)
          when 2
            # day/hour:minute
            raise ArgumentError if !is_valid_date(nil, nil, startSplitDate[0].to_i)
            startTime = find_nearest_future_date(nil, nil, startSplitDate[0].to_i, startSplitTime[0].to_i, startSplitTime[1].to_i, currentTime)
            finishTime = find_nearest_future_date(nil, nil, finishSplitDate[0].to_i, finishSplitTime[0].to_i, finishSplitTime[1].to_i, startTime)
          when 1
            # hour:minute
            startTime = find_nearest_future_date(nil, nil, nil, startSplitTime[0].to_i, startSplitTime[1].to_i, currentTime)
            finishTime = find_nearest_future_date(nil, nil, nil, finishSplitTime[0].to_i, finishSplitTime[1].to_i, startTime)
          end
        rescue => e
          msg = <<~TEXT
            不正な時刻形式，または存在しない日付です
            開始または終了時刻に誤りがあるか，無効な時刻が含まれています
          TEXT
          return [false, nil, msg]
        end

        begin
          raise ArgumentError if startTime >= finishTime
        rescue => e
          msg = <<~TEXT
            開始時刻が終了時刻よりも後，または等しくなっています
            開始時刻は終了時刻よりも前でなければなりません
          TEXT
          return [false, nil, msg]
        end

        eventInfo = {
          calendarName: calendarName,
          eventName: eventName,
          startTime: startTime,
          finishTime: finishTime
        }
        return [true, eventInfo, nil]
      end
    end # class Schedule
  end # module Resource
end # module Swimmy