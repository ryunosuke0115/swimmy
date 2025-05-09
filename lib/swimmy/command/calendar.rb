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

        arg = match[:expression]&.split(" ")
        is_valid_arg, eventInfo, msg = Swimmy::Resource::Schedule.new.arg_split(arg)
        if is_valid_arg
          msg = Swimmy::Service::Schedule.new(spreadsheet, google_oauth).add_event(eventInfo)
        end

        client.say(text: msg, channel: data.channel)
      end
    end # class Schedule
  end # module Command
end # module Swimmy