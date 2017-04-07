# encoding: utf-8
# frozen_string_literal: true

module BetaGouvBot
  class MailAction
    def initialize(client, mail)
      @client = client
      @mail = mail
    end

    def execute
      @client.post(request_body: @mail)
    end
  end
end
