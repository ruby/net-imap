# Net::IMAP

Net::IMAP implements Internet Message Access Protocol (IMAP) client
functionality.  The protocol is described in
[RFC3501](https://www.rfc-editor.org/rfc/rfc3501),
[RFC9051](https://www.rfc-editor.org/rfc/rfc9051) and various extensions.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'net-imap'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install net-imap

## Usage

### Connect with TLS to port 993

```ruby
hostname = "mail.example.com"
username = "user@example.com"
password = "correct-horse-battery-staple"

imap = Net::IMAP.new(hostname, ssl: true)
imap.authenticate(:plain, username, password)
```

To authenticate with an OAuth2 access token:
```ruby
if imap.auth_capable?(:OAUTHBEARER)
  imap.authenticate(:OAUTHBEARER, username, oauth2_token)
elsif imap.auth_capable?(:XOAUTH2)
  imap.authenticate(:XOAUTH2, username, oauth2_token)
else
  raise "OAuth2 not supported?"
end
```

### List sender and subject of recent messages

```ruby
imap.examine('INBOX')
search_result = imap.uid_search(["SINCE", Date.today - 7])
imap.uid_fetch(search_result, "ENVELOPE").each do |fetch_data|
  envelope = fetch_data.envelope
  puts "#{envelope.from.first.name}: \t#{envelope.subject}"
end
```

### Move messages between two dates to another mailbox

```ruby
source      = "Mail/sent-mail"
destination = "Mail/sent-apr03"

# The "BEFORE" and "AFTER" search criteria are not inclusive.
since  = Date.parse("2003-04-01").prev_day
before = Date.parse("2003-05-01")

if imap.list("", destination).empty?
  imap.create(destination)
end
imap.select(source)
search_result = imap.uid_search(["SINCE", since, "BEFORE", before])
if imap.capable?(:MOVE) || imap.capable?(:IMAP4rev2)
  imap.uid_move(search_result, destination)
else
  # Atomic MOVE is not supported.  Copy, delete, and expunge.
  imap.uid_copy(search_result, destination)
  imap.uid_store(search_result, "+FLAGS", [:Deleted])
  if imap.capable?(:UIDPLUS) || imap.capable?(:IMAP4rev2)
    imap.uid_expunge(search_result)
  else
    # NOTE: This may expunge _other_ deleted messages, too.
    imap.expunge
  end
end
```

## Maintenance Policy

`net-imap` is bundled with Ruby releases.  As a [bundled gem], it can be
uninstalled from a Ruby installation and must be declared in `Gemfile` when used
with `bundler`.  Each Ruby `major.minor` release series bundles a specific
`net-imap` release series.  Each `net-imap` release series will remain
compatible with at least two older versions of Ruby.

Each `net-imap` release series will receive security updates as long as they are
bundled with [supported Ruby branches].  The `net-imap` release series bundled
with Ruby's latest stable Ruby release series _may_ also receive backported
bugfixes and features, at the maintainers' discretion.

|     |Bundled with|First bundled release        |Minimum Ruby|Maintenance   |End of life |
|-----|------------|-----------------------------|------------|--------------|------------|
|0.5.x| _not yet_  | _not bundled with Ruby yet_ |Ruby 3.1    |new features  |            |
|0.4.x| Ruby 3.3   |0.4.9, Ruby 3.3.0, 2023-12-25|Ruby 2.7.3  |some backports|_2027-03-31_|
|0.3.x| Ruby 3.2   |0.3.4, Ruby 3.2.0, 2022-12-25|Ruby 2.6    |security only |_2026-03-31_|
|0.2.x| Ruby 3.1   |0.2.2, Ruby 3.1.0, 2021-12-25|Ruby 2.5/2.6|security only |_2025-03-31_|
|0.1.x| Ruby 3.0*  |0.1.1, Ruby 3.0.0, 2020-12-25|Ruby 2.5    |end of life   | 2024-04-23 |
|     | in stdlib  |       Ruby 1.6.2, 2000-12-25|            |end of life   | 2023-03-31 |

Version 0.1.x was packaged as a [default gem] for Ruby 3.0, and can not be
uninstalled from a Ruby 3.0 installation.  Before being extracted into a gem,
`net/imap` was only packaged as a part of Ruby's releases.  The first stable
release to include `net/imap` was ruby 1.6.2, on 2000-12-25.

[bundled gem]: https://docs.ruby-lang.org/en/master/standard_library_rdoc.html#label-Bundled+gems
[default gem]: https://docs.ruby-lang.org/en/master/standard_library_rdoc.html
[supported Ruby branches]: https://www.ruby-lang.org/en/downloads/branches/

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run
`bin/test` to run the tests. You can also run `bin/console` for an interactive
prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To
release a new version, update the version number in `version.rb`, and then run
`bundle exec rake release`, which will create a git tag for the version, push
git commits and tags, and push the `.gem` file to
[rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ruby/net-imap.
