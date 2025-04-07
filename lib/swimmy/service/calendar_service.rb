# coding: utf-8



module Swimmy
  module Service
    class Schedule
      def initialize(credential_path, token_path)
        # read some values from google_token_path
        credential = JSON.parse(File.open(credential_path).read)
        @client_id = credential['installed']['client_id']
        @client_secret = credential['installed']['client_secret']

        token = JSON.parse(File.open(token_path).read)
        @refresh_token = token['refresh_token']
        @expiration_time = token['expiration_time'].to_i

        # update token
        @access_tokoen = update_token()
        @last_updated_time = Time.now
      end

      # return access token
      def token
        # if current access_token expires, update token
        if expired?
          update_token()
          @last_updated_time = Time.now
        end

        @access_token
      end

      private

      # Check whether current access token is expires
      def expired?
        passed_time = Time.now - @last_updated_time
        passed_time > @expiration_time
      end

      # update token
      def update_token
        request = { refresh_token: @refresh_token,
                    client_id: @client_id,
                    client_secret: @client_secret,
                    grant_type: 'refresh_token' }
        uri = URI.parse('https://www.googleapis.com/oauth2/v4/token')

        res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          http.post(uri.request_uri, request.to_json, { 'Content-Type' => 'application/json' })
        end

        new_access_token = JSON.parse(res.body)['access_token']
        @access_token = new_access_token
      end
      # def add_schedule(calendarId, calendarName, eventName, startParams, finishParams)
      # end

    end # class Schedule
  end # module Service
end # module Swimmy