# encoding: utf-8
# frozen_string_literal: true

module BetaGouvBot
  class Webhook < Sinatra::Base
    before { content_type 'application/json; charset=utf8' }

    helpers do
      def members
        HTTParty
          .get('https://beta.gouv.fr/api/v1.3/authors.json')
          .parsed_response
          .map(&:with_indifferent_access)
      end
    end

    get '/actions' do
      date = params.key?('date') ? Date.iso8601(params['date']) : Date.today
      execute = params.key?('secret') && (params['secret'] == ENV['SECRET'])

      # Send contract expiration reminders (if any)
      notifications = NotificationRequest.(members, date)

      # Reconcile mailing lists
      sorting_hat = SortingHat.(members, date)

      # Manage Github membership
      github = GithubRequest.(members, date)

      # Execute actions
      (mailer + sorting_hat + github).map(&:execute) if execute

      # Debug
      {
        "execute": execute,
        "notifications": notifications,
        "sorting_hat": sorting_hat,
        "github": github
      }.to_json
    end

    post '/badge' do
      badges  = BadgeRequest.(members, params['text'])
      execute = params.key?('token') && (params['token'] == ENV['BADGE_TOKEN'])
      badges.map(&:execute) if execute
      { response_type: 'in_channel', text: 'OK, demande faite !' }.to_json
    end

    # Debug
    get '/badge' do
      { "badges": BadgeRequest.(members, params['text']) }.to_json
    end

    post '/compte' do
      member, email, password = params['text'].to_s.split
      account_request         = AccountRequest.new(members, member, email, password)

      account_request.on(:success) do |accounts|
        # Notify request is valid and being treated...
        origin   = params['user_name']
        response = "A la demande de @#{origin} je créée un compte pour #{member}"
        body     = { response_type: 'in_channel', text: response }.to_json
        HTTParty.post(params['response_url'], body: body, headers: headers)

        execute = params.key?('token') && (params['token'] == ENV['COMPTE_TOKEN'])
        accounts.map(&:execute) if execute

        # Notify request has been treated...
        response = 'OK, création de compte en cours !'
        body     = { text: response }.to_json
        HTTParty.post(params['response_url'], body: body, headers: headers)
      end

      account_request.on(:not_found) do
        response = 'Je ne vois pas de qui tu veux parler'
        body     = { text: response }.to_json
        HTTParty.post(params['response_url'], body: body, headers: headers)
      end

      account_request.on(:error) do |errors|
        body = { text: errors.first }.to_json
        HTTParty.post(params['response_url'], body: body, headers: headers)
        raise(StandardError, errors.first)
      end

      account_request.()

      # Explicitly return empty response to suppress echoing of the command
      ''
    end

    # Debug
    get '/compte' do
      { "comptes": AccountRequest.(members, *params['text'].to_s.split) }.to_json
    end

    ## Noop
    error StandardError do
      "Zut, il y a une erreur: #{env['sinatra.error'].message}"
    end
  end
end
