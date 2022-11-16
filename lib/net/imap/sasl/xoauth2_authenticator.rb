# frozen_string_literal: true

# Authenticator for the "+XOAUTH2+" SASL mechanism.  This mechanism was
# originally created for GMail and widely adopted by hosted email providers.
# +XOAUTH2+ has been documented by
# Google[https://developers.google.com/gmail/imap/xoauth2-protocol] and
# Microsoft[https://learn.microsoft.com/en-us/exchange/client-developer/legacy-protocols/how-to-authenticate-an-imap-pop-smtp-application-by-using-oauth].
#
# This mechanism requires an OAuth2 +access_token+ which has been authorized
# with the appropriate OAuth2 scopes to access IMAP.  These scopes are not
# standardized---consult each email service provider's documentation.
#
# Although this mechanism was never standardized and has been obsoleted by
# "+OAUTHBEARER+", it is still very widely supported.
#
# See Net::IMAP::SASL:: OAuthBearerAuthenticator.
class Net::IMAP::SASL::XOAuth2Authenticator

  # It is unclear from {Google's original XOAUTH2
  # documentation}[https://developers.google.com/gmail/imap/xoauth2-protocol],
  # whether "User" refers to the authentication identity (+authcid+) or the
  # authorization identity (+authzid+).  It appears to behave as +authzid+.
  #
  # {Microsoft's documentation for shared
  # mailboxes}[https://learn.microsoft.com/en-us/exchange/client-developer/legacy-protocols/how-to-authenticate-an-imap-pop-smtp-application-by-using-oauth#sasl-xoauth2-authentication-for-shared-mailboxes-in-office-365]
  # clearly indicate that the Office 365 server interprets it as the
  # authorization identity.
  attr_reader :username

  # An OAuth2 access token which has been authorized with the appropriate OAuth2
  # scopes to use the service for #username.
  attr_reader :oauth2_token

  # :call-seq:
  #   new(username,  oauth2_token,  **) -> authenticator
  #   new(username:, oauth2_token:, **) -> authenticator
  #
  # Creates an Authenticator for the "+XOAUTH2+" SASL mechanism, as specified by
  # Google[https://developers.google.com/gmail/imap/xoauth2-protocol],
  # Microsoft[https://learn.microsoft.com/en-us/exchange/client-developer/legacy-protocols/how-to-authenticate-an-imap-pop-smtp-application-by-using-oauth]
  # and Yahoo[https://senders.yahooinc.com/developer/documentation].
  #
  # === Properties
  #
  # * #username --- the username for the account being accessed.
  # * #oauth2_token --- An OAuth2.0 access token which is authorized to access
  #   the service for #username.
  #
  # See the documentation for each attribute for more details.
  def initialize(user = nil, token = nil, username: nil, oauth2_token: nil, **)
    @username = username || user or
      raise ArgumentError, "missing username"
    @oauth2_token = oauth2_token || token or
      raise ArgumentError, "missing oauth2_token"
    [username, user].compact.count == 1 or
      raise ArgumentError, "conflicting values for username"
    [oauth2_token, token].compact.count == 1 or
      raise ArgumentError, "conflicting values for oauth2_token"
    @done = false
  end

  # :call-seq:
  #   initial_response? -> true
  #
  # +PLAIN+ can send an initial client response.
  def initial_response?; true end

  # Returns the XOAUTH2 formatted response, which combines the +username+
  # with the +oauth2_token+.
  def process(_data)
    build_oauth2_string(@username, @oauth2_token)
  ensure
    @done = true
  end

  # Returns true when the initial client response was sent.
  #
  # The authentication should not succeed unless this returns true, but it
  # does *not* indicate success.
  def done?; @done end

  private

  def build_oauth2_string(username, oauth2_token)
    format("user=%s\1auth=Bearer %s\1\1", username, oauth2_token)
  end

end
