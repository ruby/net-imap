# Net::IMAP

Net::IMAP implements Internet Message Access Protocol (IMAP) client
functionality.  The protocol is described in [IMAP](https://tools.ietf.org/html/rfc3501).

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
imap = Net::IMAP.new('mail.example.com', ssl: true)
imap.port          => 993
imap.tls_verified? => true
case imap.greeting.name
in /OK/i
  # The client is connected in the "Not Authenticated" state.
  imap.authenticate("PLAIN", "joe_user", "joes_password")
in /PREAUTH/i
  # The client is connected in the "Authenticated" state.
end
```

### List sender and subject of all recent messages in the default mailbox

```ruby
imap.examine('INBOX')
imap.search(["RECENT"]).each do |message_id|
  envelope = imap.fetch(message_id, "ENVELOPE")[0].attr["ENVELOPE"]
  puts "#{envelope.from[0].name}: \t#{envelope.subject}"
end
```

### Move all messages from April 2003 from "Mail/sent-mail" to "Mail/sent-apr03"

```ruby
imap.select('Mail/sent-mail')
if not imap.list('Mail/', 'sent-apr03')
  imap.create('Mail/sent-apr03')
end
imap.search(["BEFORE", "30-Apr-2003", "SINCE", "1-Apr-2003"]).each do |message_id|
  imap.copy(message_id, "Mail/sent-apr03")
  imap.store(message_id, "+FLAGS", [:Deleted])
end
imap.expunge
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

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bundle exec rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ruby/net-imap.
