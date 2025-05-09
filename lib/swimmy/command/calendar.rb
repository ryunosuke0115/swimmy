# coding: utf-8

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
          is_valid_arg, eventInfo, msg = Swimmy::Resource::Schedule.new.arg_split(arg)
          if is_valid_arg
            msg = Swimmy::Service::Schedule.new(spreadsheet, google_oauth).add_event(eventInfo)
          end
        else
          msg = <<~TEXT
            calendar <カレンダー名> <予定名> <開始時刻> <終了時刻> - 指定されたカレンダーに予定を追加します
            開始・終了時刻の形式は以下のいずれかであり，統一される必要があります
            1. 時刻のみ - 例: "10:00"
            2. 日/時刻 - 例: "18/10:00"
            3. 月/日/時刻 - 例: "4/18/10:00"
            4. 年/月/日/時刻 - 例: "2023/4/18/10:00"
          TEXT
        end
        client.say(text: msg, channel: data.channel)
      end
    end # class Schedule
  end # module Command
end # module Swimmy