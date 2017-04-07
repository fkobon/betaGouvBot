# encoding: utf-8
# frozen_string_literal: true

require 'betagouvbot/anticipator'
require 'betagouvbot/mailer'
require 'betagouvbot/sortinghat'
require 'sinatra/base'
require 'sendgrid-ruby'
require 'httparty'
require 'liquid'

module BetaGouvBot
  HORIZONS = [21, 14, 1, -1].freeze
  RULES = Hash[HORIZONS.map { |days| [days, File.read("data/body_#{days}.txt")] }]

  class Webhook < Sinatra::Base
    get '/actions' do
      date = params.key?('date') ? Date.iso8601(params['date']) : Date.today
      dry_run = params.key?('dry_run')
      # Read beta.gouv.fr members' API
      members = HTTParty.get('https://beta.gouv.fr/api/v1.1/authors.json').parsed_response

      # Parse into a schedule of notifications
      warnings = Anticipator.(members, RULES.keys, date)

      # Send reminders (if any)
      mailer = Mailer.(warnings, RULES, dry_run)

      # Reconcile mailing lists
      sorting_hat = SortingHat.(members, date, dry_run)
      { "warnings": warnings, "mailer": mailer, "sorting_hat": sorting_hat }.to_json
    end
  end
end
