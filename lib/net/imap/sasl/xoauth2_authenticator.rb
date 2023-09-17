# frozen_string_literal: true

class Net::IMAP::SASL::XOAuth2Authenticator

  def initialize(user, oauth2_token)
    @user = user
    @oauth2_token = oauth2_token
  end

  def initial_response?; true end

  def process(_data)
    build_oauth2_string(@user, @oauth2_token)
  end

  private

  def build_oauth2_string(user, oauth2_token)
    format("user=%s\1auth=Bearer %s\1\1", user, oauth2_token)
  end

end
