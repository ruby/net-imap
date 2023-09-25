# frozen_string_literal: true

# Authenticator for the "+PLAIN+" SASL mechanism, specified in
# RFC-4616[https://tools.ietf.org/html/rfc4616].  See Net::IMAP#authenticate.
#
# +PLAIN+ authentication sends the password in cleartext.
# RFC-3501[https://tools.ietf.org/html/rfc3501] encourages servers to disable
# cleartext authentication until after TLS has been negotiated.
# RFC-8314[https://tools.ietf.org/html/rfc8314] recommends TLS version 1.2 or
# greater be used for all traffic, and deprecate cleartext access ASAP.  +PLAIN+
# can be secured by TLS encryption.
class Net::IMAP::SASL::PlainAuthenticator

  NULL = -"\0".b
  private_constant :NULL

  # Authentication identity: the identity that matches the #password.
  #
  # RFC-2831[https://tools.ietf.org/html/rfc2831] uses the term +username+.
  # "Authentication identity" is the generic term used by
  # RFC-4422[https://tools.ietf.org/html/rfc4422].
  # RFC-4616[https://tools.ietf.org/html/rfc4616] and many later RFCs abbreviate
  # this to +authcid+.
  attr_reader :username

  # A password or passphrase that matches the #username.
  attr_reader :password

  # Authorization identity: an identity to act as or on behalf of.  The identity
  # form is application protocol specific.  If not provided or left blank, the
  # server derives an authorization identity from the authentication identity.
  # The server is responsible for verifying the client's credentials and
  # verifying that the identity it associates with the client's authentication
  # identity is allowed to act as (or on behalf of) the authorization identity.
  #
  # For example, an administrator or superuser might take on another role:
  #
  #     imap.authenticate "PLAIN", "root", passwd, authzid: "user"
  #
  attr_reader :authzid

  # :call-seq:
  #   new(username,  password,  authzid: nil, **) -> authenticator
  #   new(username:, password:, authzid: nil, **) -> authenticator
  #
  # Creates an Authenticator for the "+PLAIN+" SASL mechanism.
  #
  # Called by Net::IMAP#authenticate and similar methods on other clients.
  #
  # === Parameters
  #
  # * #username ― Identity whose +password+ is used.
  # * #password ― Password or passphrase associated with this username+.
  # * #authzid ― Alternate identity to act as or on behalf of.  Optional.
  #
  # See attribute documentation for more details.
  def initialize(user = nil, pass = nil,
                 username: nil, password: nil, authzid: nil, **)
    [username, user].compact.count == 1 or
      raise ArgumentError, "conflicting values for username"
    [password, pass].compact.count == 1 or
      raise ArgumentError, "conflicting values for password"
    username ||= user or raise ArgumentError, "missing username"
    password ||= pass or raise ArgumentError, "missing password"
    raise ArgumentError, "username contains NULL" if username.include?(NULL)
    raise ArgumentError, "password contains NULL" if password.include?(NULL)
    raise ArgumentError, "authzid contains NULL"  if authzid&.include?(NULL)
    @username = username
    @password = password
    @authzid  = authzid
    @done = false
  end

  # :call-seq:
  #   initial_response? -> true
  #
  # +PLAIN+ can send an initial client response.
  def initial_response?; true end

  # Responds with the client's credentials.
  def process(data)
    return "#@authzid\0#@username\0#@password"
  ensure
    @done = true
  end

  # Returns true when the initial client response was sent.
  #
  # The authentication should not succeed unless this returns true, but it
  # does *not* indicate success.
  def done?; @done end

end
