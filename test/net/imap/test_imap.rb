# frozen_string_literal: true

require "net/imap"
require "test/unit"
require_relative "fake_server"

class IMAPTest < Test::Unit::TestCase
  CA_FILE = File.expand_path("../fixtures/cacert.pem", __dir__)
  SERVER_KEY = File.expand_path("../fixtures/server.key", __dir__)
  SERVER_CERT = File.expand_path("../fixtures/server.crt", __dir__)

  include Net::IMAP::FakeServer::TestHelper

  def setup
    Net::IMAP.config.reset
    @do_not_reverse_lookup = Socket.do_not_reverse_lookup
    Socket.do_not_reverse_lookup = true
    @threads = []
  end

  def teardown
    if !@threads.empty?
      assert_join_threads(@threads)
    end
  ensure
    Socket.do_not_reverse_lookup = @do_not_reverse_lookup
  end

  if defined?(OpenSSL::SSL::SSLError)
    def test_imaps_unknown_ca
      assert_raise(OpenSSL::SSL::SSLError) do
        imaps_test do |port|
          begin
            Net::IMAP.new("localhost",
                          :port => port,
                          :ssl => true)
          rescue SystemCallError
            skip $!
          end
        end
      end
    end

    def test_imaps_with_ca_file
      # Assert verified *after* the imaps_test and assert_nothing_raised blocks.
      # Otherwise, failures can't logout and need to wait for the timeout.
      verified, imap = :unknown, nil
      assert_nothing_raised do
        imaps_test do |port|
          imap = Net::IMAP.new("localhost",
                               port: port,
                               ssl: { :ca_file => CA_FILE })
          verified = imap.tls_verified?
          imap
        rescue SystemCallError
          skip $!
        end
      end
      assert_equal true, verified
      assert_equal true, imap.tls_verified?
      assert_equal({ca_file: CA_FILE}, imap.ssl_ctx_params)
      assert_equal(CA_FILE, imap.ssl_ctx.ca_file)
      assert_equal(OpenSSL::SSL::VERIFY_PEER, imap.ssl_ctx.verify_mode)
      assert imap.ssl_ctx.verify_hostname
    end

    def test_imaps_verify_none
      # Assert verified *after* the imaps_test and assert_nothing_raised blocks.
      # Otherwise, failures can't logout and need to wait for the timeout.
      verified, imap = :unknown, nil
      assert_nothing_raised do
        imaps_test do |port|
          imap = Net::IMAP.new(
            server_addr,
            port: port,
            ssl: { :verify_mode => OpenSSL::SSL::VERIFY_NONE }
          )
          verified = imap.tls_verified?
          imap
        end
      end
      assert_equal false, verified
      assert_equal false, imap.tls_verified?
      assert_equal({verify_mode: OpenSSL::SSL::VERIFY_NONE},
                   imap.ssl_ctx_params)
      assert_equal(nil, imap.ssl_ctx.ca_file)
      assert_equal(OpenSSL::SSL::VERIFY_NONE, imap.ssl_ctx.verify_mode)
    end

    def test_imaps_post_connection_check
      assert_raise(OpenSSL::SSL::SSLError) do
        imaps_test do |port|
          # server_addr is different from the hostname in the certificate,
          # so the following code should raise a SSLError.
          Net::IMAP.new(server_addr,
                        :port => port,
                        :ssl => { :ca_file => CA_FILE })
        end
      end
    end
  end

  if defined?(OpenSSL::SSL)
    def test_starttls_unknown_ca
      omit "This test is not working with Windows" if RUBY_PLATFORM =~ /mswin|mingw/

      imap = nil
      assert_raise(OpenSSL::SSL::SSLError) do
        ex = nil
        starttls_test do |port|
          imap = Net::IMAP.new("localhost", port: port)
          imap.starttls
          imap
        rescue => ex
          imap
        end
        raise ex if ex
      end
      assert_equal false, imap.tls_verified?
      assert_equal({}, imap.ssl_ctx_params)
      assert_equal(nil, imap.ssl_ctx.ca_file)
      assert_equal(OpenSSL::SSL::VERIFY_PEER, imap.ssl_ctx.verify_mode)
    end

    def test_starttls
      initial_verified, initial_ctx, initial_params = :unknown, :unknown, :unknown
      imap = nil
      starttls_test do |port|
        imap = Net::IMAP.new("localhost", :port => port)
        initial_verified = imap.tls_verified?
        initial_params   = imap.ssl_ctx_params
        initial_ctx      = imap.ssl_ctx
        imap.starttls(:ca_file => CA_FILE)
        imap
      end
      assert_equal false, initial_verified
      assert_equal false, initial_params
      assert_equal nil,   initial_ctx
      assert_equal true, imap.tls_verified?
      assert_equal({ca_file: CA_FILE}, imap.ssl_ctx_params)
    rescue SystemCallError
      skip $!
    ensure
      if imap && !imap.disconnected?
        imap.disconnect
      end
    end

    def test_starttls_stripping
      imap = nil
      starttls_stripping_test do |port|
        imap = Net::IMAP.new("localhost", :port => port)
        assert_raise(Net::IMAP::InvalidResponseError) do
          imap.starttls(:ca_file => CA_FILE)
        end
        assert imap.disconnected?
        imap
      end
      assert_equal false, imap.tls_verified?
      assert_equal({ca_file: CA_FILE},        imap.ssl_ctx_params)
      assert_equal(CA_FILE,                   imap.ssl_ctx.ca_file)
      assert_equal(OpenSSL::SSL::VERIFY_PEER, imap.ssl_ctx.verify_mode)
    end
  end

  def start_server
    th = Thread.new do
      yield
    end
    @threads << th
    sleep 0.1 until th.stop?
  end

  def test_unexpected_eof
    server = create_tcp_server
    port = server.addr[1]
    start_server do
      sock = server.accept
      begin
        sock.print("* OK test server\r\n")
        sock.gets
#       sock.print("* BYE terminating connection\r\n")
#       sock.print("RUBY0001 OK LOGOUT completed\r\n")
      ensure
        sock.close
        server.close
      end
    end
    begin
      imap = Net::IMAP.new(server_addr, :port => port)
      assert_raise(EOFError) do
        imap.logout
      end
    ensure
      imap.disconnect if imap
    end
  end

  def test_idle
    server = create_tcp_server
    port = server.addr[1]
    requests = []
    start_server do
      sock = server.accept
      begin
        sock.print("* OK test server\r\n")
        requests.push(sock.gets)
        sock.print("+ idling\r\n")
        sock.print("* 3 EXISTS\r\n")
        sock.print("* 2 EXPUNGE\r\n")
        requests.push(sock.gets)
        sock.print("RUBY0001 OK IDLE terminated\r\n")
        sock.gets
        sock.print("* BYE terminating connection\r\n")
        sock.print("RUBY0002 OK LOGOUT completed\r\n")
      ensure
        sock.close
        server.close
      end
    end

    begin
      imap = Net::IMAP.new(server_addr, :port => port)
      responses = []
      imap.idle do |res|
        responses.push(res)
        if res.name == "EXPUNGE"
          imap.idle_done
        end
      end
      assert_equal(3, responses.length)
      assert_instance_of(Net::IMAP::ContinuationRequest, responses[0])
      assert_equal("EXISTS", responses[1].name)
      assert_equal(3, responses[1].data)
      assert_equal("EXPUNGE", responses[2].name)
      assert_equal(2, responses[2].data)
      assert_equal(2, requests.length)
      assert_equal("RUBY0001 IDLE\r\n", requests[0])
      assert_equal("DONE\r\n", requests[1])
      imap.logout
    ensure
      imap.disconnect if imap
    end
  end

  def test_exception_during_idle
    server = create_tcp_server
    port = server.addr[1]
    requests = []
    start_server do
      sock = server.accept
      begin
        sock.print("* OK test server\r\n")
        requests.push(sock.gets)
        sock.print("+ idling\r\n")
        sock.print("* 3 EXISTS\r\n")
        sock.print("* 2 EXPUNGE\r\n")
        requests.push(sock.gets)
        sock.print("RUBY0001 OK IDLE terminated\r\n")
        sock.gets
        sock.print("* BYE terminating connection\r\n")
        sock.print("RUBY0002 OK LOGOUT completed\r\n")
      ensure
        sock.close
        server.close
      end
    end
    begin
      imap = Net::IMAP.new(server_addr, :port => port)
      begin
        th = Thread.current
        m = Monitor.new
        in_idle = false
        exception_raised = false
        c = m.new_cond
        raiser = Thread.start do
          m.synchronize do
            until in_idle
              c.wait(0.1)
            end
          end
          th.raise(Interrupt)
          m.synchronize do
            exception_raised = true
            c.signal
          end
        end
        @threads << raiser
        imap.idle do |res|
          m.synchronize do
            in_idle = true
            c.signal
            until exception_raised
              c.wait(0.1)
            end
          end
        end
      rescue Interrupt
      end
      assert_equal(2, requests.length)
      assert_equal("RUBY0001 IDLE\r\n", requests[0])
      assert_equal("DONE\r\n", requests[1])
      imap.logout
    ensure
      imap.disconnect if imap
      raiser.kill unless in_idle
    end
  end

  def test_idle_done_not_during_idle
    server = create_tcp_server
    port = server.addr[1]
    start_server do
      sock = server.accept
      begin
        sock.print("* OK test server\r\n")
        sleep 0.1
      ensure
        sock.close
        server.close
      end
    end
    begin
      imap = Net::IMAP.new(server_addr, :port => port)
      assert_raise(Net::IMAP::Error) do
        imap.idle_done
      end
    ensure
      imap.disconnect if imap
    end
  end

  def test_idle_timeout
    server = create_tcp_server
    port = server.addr[1]
    requests = []
    start_server do
      sock = server.accept
      begin
        sock.print("* OK test server\r\n")
        requests.push(sock.gets)
        sock.print("+ idling\r\n")
        sock.print("* 3 EXISTS\r\n")
        sock.print("* 2 EXPUNGE\r\n")
        requests.push(sock.gets)
        sock.print("RUBY0001 OK IDLE terminated\r\n")
        sock.gets
        sock.print("* BYE terminating connection\r\n")
        sock.print("RUBY0002 OK LOGOUT completed\r\n")
      ensure
        sock.close
        server.close
      end
    end

    begin
      imap = Net::IMAP.new(server_addr, :port => port)
      responses = []
      Thread.pass
      imap.idle(0.2) do |res|
        responses.push(res)
      end
      # There is no guarantee that this thread has received all the responses,
      # so check the response length.
      if responses.length > 0
        assert_instance_of(Net::IMAP::ContinuationRequest, responses[0])
        if responses.length > 1
          assert_equal("EXISTS", responses[1].name)
          assert_equal(3, responses[1].data)
          if responses.length > 2
            assert_equal("EXPUNGE", responses[2].name)
            assert_equal(2, responses[2].data)
          end
        end
      end
      # Also, there is no guarantee that the server thread has stored
      # all the requests into the array, so check the length.
      if requests.length > 0
        assert_equal("RUBY0001 IDLE\r\n", requests[0])
        if requests.length > 1
          assert_equal("DONE\r\n", requests[1])
        end
      end
      imap.logout
    ensure
      imap.disconnect if imap
    end
  end

  def test_unexpected_bye
    server = create_tcp_server
    port = server.addr[1]
    start_server do
      sock = server.accept
      begin
        sock.print("* OK Gimap ready for requests from 75.101.246.151 33if2752585qyk.26\r\n")
        sock.gets
        sock.print("* BYE System Error 33if2752585qyk.26\r\n")
      ensure
        sock.close
        server.close
      end
    end
    begin
      imap = Net::IMAP.new(server_addr, :port => port)
      assert_raise(Net::IMAP::ByeResponseError) do
        imap.login("user", "password")
      end
    end
  end

  def test_exception_during_shutdown
    server = create_tcp_server
    port = server.addr[1]
    start_server do
      sock = server.accept
      begin
        sock.print("* OK test server\r\n")
        sock.gets
        sock.print("* BYE terminating connection\r\n")
        sock.print("RUBY0001 OK LOGOUT completed\r\n")
      ensure
        sock.close
        server.close
      end
    end
    begin
      imap = Net::IMAP.new(server_addr, :port => port)
      imap.instance_eval do
        def @sock.shutdown(*args)
          super
        ensure
          raise "error"
        end
      end
      imap.logout
    ensure
      assert_raise(RuntimeError) do
        imap.disconnect
      end
    end
  end

  def test_connection_closed_during_idle
    server = create_tcp_server
    port = server.addr[1]
    requests = []
    sock = nil
    threads = []
    started = false
    threads << Thread.start do
      started = true
      begin
        sock = server.accept
        sock.print("* OK test server\r\n")
        requests.push(sock.gets)
        sock.print("+ idling\r\n")
      rescue IOError # sock is closed by another thread
      ensure
        server.close
      end
    end
    sleep 0.1 until started
    threads << Thread.start do
      imap = Net::IMAP.new(server_addr, :port => port)
      begin
        m = Monitor.new
        in_idle = false
        closed = false
        c = m.new_cond
        threads << Thread.start do
          m.synchronize do
            until in_idle
              c.wait(0.1)
            end
          end
          sock.close
          m.synchronize do
            closed = true
            c.signal
          end
        end
        assert_raise(EOFError) do
          imap.idle do |res|
            m.synchronize do
              in_idle = true
              c.signal
              until closed
                c.wait(0.1)
              end
            end
          end
        end
        assert_equal(1, requests.length)
        assert_equal("RUBY0001 IDLE\r\n", requests[0])
      ensure
        imap.disconnect if imap
      end
    end
    assert_join_threads(threads)
  ensure
    if sock && !sock.closed?
      sock.close
    end
  end

  def test_connection_closed_without_greeting
    server = create_tcp_server
    port = server.addr[1]
    h = {
      server: server,
      port: port,
      server_created: {
        server: server.inspect,
        t: Process.clock_gettime(Process::CLOCK_MONOTONIC),
      }
    }
    net_imap = Class.new(Net::IMAP) do
      @@h = h
      def tcp_socket(host, port)
        @@h[:in_tcp_socket] = {
          host: host,
          port: port,
          server: @@h[:server].inspect,
          t: Process.clock_gettime(Process::CLOCK_MONOTONIC),
        }
        #super
        s = Socket.tcp(host, port)
        @@h[:in_tcp_socket_2] = {
          s: s.inspect,
          local_address: s.local_address,
          remote_address: s.remote_address,
          t: Process.clock_gettime(Process::CLOCK_MONOTONIC),
        }
        s.setsockopt(:SOL_SOCKET, :SO_KEEPALIVE, true)
        s
      end
    end
    start_server do
      begin
        h[:in_start_server_before_accept] = {
          t: Process.clock_gettime(Process::CLOCK_MONOTONIC),
        }
        sock = server.accept
        h[:in_start_server] = {
          sock_addr: sock.addr,
          sock_peeraddr: sock.peeraddr,
          t: Process.clock_gettime(Process::CLOCK_MONOTONIC),
          sockets: ObjectSpace.each_object(BasicSocket).map{|s| [s.inspect, connect_address: (s.connect_address rescue nil).inspect, local_address: (s.local_address rescue nil).inspect, remote_address: (s.remote_address rescue nil).inspect] },
        }
        sock.close
        h[:in_start_server_sock_closed] = {
          t: Process.clock_gettime(Process::CLOCK_MONOTONIC),
        }
      ensure
        server.close
      end
    end
    assert_raise(Net::IMAP::Error) do
      #Net::IMAP.new(server_addr, :port => port)
      if true
          net_imap.new(server_addr, :port => port)
      else
        # for testing debug print
        begin
          net_imap.new(server_addr, :port => port)
        rescue Net::IMAP::Error
          raise Errno::EINVAL
        end
      end
    rescue SystemCallError => e # for debug on OpenCSW
      h[:in_rescue] = {
        e: e,
        server_addr: server_addr,
        t: Process.clock_gettime(Process::CLOCK_MONOTONIC),
      }
      require 'pp'
      raise(PP.pp(h, +''))
    end
  end

  def test_default_port
    assert_equal(143, Net::IMAP.default_port)
    assert_equal(143, Net::IMAP.default_imap_port)
    assert_equal(993, Net::IMAP.default_tls_port)
    assert_equal(993, Net::IMAP.default_ssl_port)
    assert_equal(993, Net::IMAP.default_imaps_port)
  end

  def test_send_invalid_number
    server = create_tcp_server
    port = server.addr[1]
    start_server do
      sock = server.accept
      begin
        sock.print("* OK test server\r\n")
        sock.gets # Integer: 0
        sock.print("RUBY0001 OK TEST completed\r\n")
        sock.gets # Integer: 2**32 - 1
        sock.print("RUBY0002 OK TEST completed\r\n")
        sock.gets # MessageSet: 1
        sock.print("RUBY0003 OK TEST completed\r\n")
        sock.gets # MessageSet: 2**32 - 1
        sock.print("RUBY0004 OK TEST completed\r\n")
        sock.gets # SequenceSet: -1 => "*"
        sock.print("RUBY0005 OK TEST completed\r\n")
        sock.gets # SequenceSet: 1
        sock.print("RUBY0006 OK TEST completed\r\n")
        sock.gets # SequenceSet: 2**32 - 1
        sock.print("RUBY0007 OK TEST completed\r\n")
        sock.gets # LOGOUT
        sock.print("* BYE terminating connection\r\n")
        sock.print("RUBY0008 OK LOGOUT completed\r\n")
      ensure
        sock.close
        server.close
      end
    end
    begin
      # regular numbers may be any uint32
      imap = Net::IMAP.new(server_addr, :port => port)
      assert_raise(Net::IMAP::DataFormatError) do
        imap.__send__(:send_command, "TEST", -1)
      end
      imap.__send__(:send_command, "TEST", 0)
      imap.__send__(:send_command, "TEST", 2**32 - 1)
      assert_raise(Net::IMAP::DataFormatError) do
        imap.__send__(:send_command, "TEST", 2**32)
      end
      # MessageSet numbers may be non-zero uint32
      stderr = EnvUtil.verbose_warning do
        assert_raise(Net::IMAP::DataFormatError) do
          imap.__send__(:send_command, "TEST", Net::IMAP::MessageSet.new(-1))
        end
        assert_raise(Net::IMAP::DataFormatError) do
          imap.__send__(:send_command, "TEST", Net::IMAP::MessageSet.new(0))
        end
        imap.__send__(:send_command, "TEST", Net::IMAP::MessageSet.new(1))
        imap.__send__(:send_command, "TEST", Net::IMAP::MessageSet.new(2**32 - 1))
        assert_raise(Net::IMAP::DataFormatError) do
          imap.__send__(:send_command, "TEST", Net::IMAP::MessageSet.new(2**32))
        end
      end
      assert_match(/DEPRECATED:.+MessageSet.+replace.+with.+SequenceSet/, stderr)
      # SequenceSet numbers may be non-zero uint3, and -1 is translated to *
      imap.__send__(:send_command, "TEST", Net::IMAP::SequenceSet.new(-1))
      assert_raise(Net::IMAP::DataFormatError) do
        imap.__send__(:send_command, "TEST", Net::IMAP::SequenceSet.new(0))
      end
      imap.__send__(:send_command, "TEST", Net::IMAP::SequenceSet.new(1))
      imap.__send__(:send_command, "TEST", Net::IMAP::SequenceSet.new(2**32-1))
      assert_raise(Net::IMAP::DataFormatError) do
        imap.__send__(:send_command, "TEST", Net::IMAP::SequenceSet.new(2**32))
      end
      imap.logout
    ensure
      imap.disconnect
    end
  end

  test("send PartialRange args") do
    with_fake_server do |server, imap|
      server.on "TEST", &:done_ok
      send_partial_ranges = ->(*args) do
        args.map! { Net::IMAP::PartialRange[_1] }
        imap.__send__(:send_command, "TEST", *args)
      end
      # simple strings
      send_partial_ranges.call "1:5", "-5:-1"
      assert_equal "1:5 -5:-1", server.commands.pop.args
      # backwards strings are reversed
      send_partial_ranges.call "5:1", "-1:-5"
      assert_equal "1:5 -5:-1", server.commands.pop.args
      # simple ranges
      send_partial_ranges.call 1..5, -5..-1
      assert_equal "1:5 -5:-1", server.commands.pop.args
      # exclusive ranges drop end
      send_partial_ranges.call 1...5, -5...-1
      assert_equal "1:4 -5:-2", server.commands.pop.args

      # backwards ranges are invalid
      assert_raise(ArgumentError) do send_partial_ranges.call( 5.. 1) end
      assert_raise(ArgumentError) do send_partial_ranges.call(-1..-5) end

      # bounds checks
      uint32_max = 2**32 - 1
      not_uint32 = 2**32
      send_partial_ranges.call 500..uint32_max
      assert_equal "500:#{uint32_max}", server.commands.pop.args
      send_partial_ranges.call 500...not_uint32
      assert_equal "500:#{uint32_max}", server.commands.pop.args
      send_partial_ranges.call "#{uint32_max}:500"
      assert_equal "500:#{uint32_max}", server.commands.pop.args

      send_partial_ranges.call(-uint32_max..-500)
      assert_equal "-#{uint32_max}:-500", server.commands.pop.args
      send_partial_ranges.call "-500:-#{uint32_max}"
      assert_equal "-#{uint32_max}:-500", server.commands.pop.args

      assert_raise(ArgumentError) do send_partial_ranges.call("foo") end
      assert_raise(ArgumentError) do send_partial_ranges.call("foo:bar") end
      assert_raise(ArgumentError) do send_partial_ranges.call("1.2:3.5") end
      assert_raise(ArgumentError) do send_partial_ranges.call("1:*") end
      assert_raise(ArgumentError) do send_partial_ranges.call("1:#{not_uint32}") end
      assert_raise(ArgumentError) do send_partial_ranges.call(1..) end
      assert_raise(ArgumentError) do send_partial_ranges.call(1..not_uint32) end
      assert_raise(ArgumentError) do send_partial_ranges.call(..1) end
    end
  end

  def test_send_literal
    server = create_tcp_server
    port = server.addr[1]
    requests = []
    literal = nil
    start_server do
      sock = server.accept
      begin
        sock.print("* OK test server\r\n")
        line = sock.gets
        requests.push(line)
        size = line.slice(/{(\d+)}\r\n/, 1).to_i
        sock.print("+ Ready for literal data\r\n")
        literal = sock.read(size)
        requests.push(sock.gets)
        sock.print("RUBY0001 OK TEST completed\r\n")
        sock.gets
        sock.print("* BYE terminating connection\r\n")
        sock.print("RUBY0002 OK LOGOUT completed\r\n")
      ensure
        sock.close
        server.close
      end
    end
    begin
      imap = Net::IMAP.new(server_addr, :port => port)
      imap.__send__(:send_command, "TEST", ["\xDE\xAD\xBE\xEF".b])
      assert_equal(2, requests.length)
      assert_equal("RUBY0001 TEST ({4}\r\n", requests[0])
      assert_equal("\xDE\xAD\xBE\xEF".b, literal)
      assert_equal(")\r\n", requests[1])
      imap.logout
    ensure
      imap.disconnect
    end
  end

  def test_disconnect
    server = create_tcp_server
    port = server.addr[1]
    start_server do
      sock = server.accept
      begin
        sock.print("* OK test server\r\n")
        sock.gets
        sock.print("* BYE terminating connection\r\n")
        sock.print("RUBY0001 OK LOGOUT completed\r\n")
      ensure
        sock.close
        server.close
      end
    end
    begin
      imap = Net::IMAP.new(server_addr, :port => port)
      imap.logout
      imap.disconnect
      assert_equal(true, imap.disconnected?)
      imap.disconnect
      assert_equal(true, imap.disconnected?)
    ensure
      imap.disconnect if imap && !imap.disconnected?
    end
  end

  def test_append
    server = create_tcp_server
    port = server.addr[1]
    mail = <<EOF.gsub(/\n/, "\r\n")
From: shugo@example.com
To: matz@example.com
Subject: hello

hello world
EOF
    requests = []
    received_mail = nil
    start_server do
      sock = server.accept
      begin
        sock.print("* OK test server\r\n")
        line = sock.gets
        requests.push(line)
        size = line.slice(/{(\d+)}\r\n/, 1).to_i
        sock.print("+ Ready for literal data\r\n")
        received_mail = sock.read(size)
        sock.gets
        sock.print("RUBY0001 OK APPEND completed\r\n")
        requests.push(sock.gets)
        sock.print("* BYE terminating connection\r\n")
        sock.print("RUBY0002 OK LOGOUT completed\r\n")
      ensure
        sock.close
        server.close
      end
    end

    begin
      imap = Net::IMAP.new(server_addr, :port => port)
      imap.append("INBOX", mail)
      assert_equal(1, requests.length)
      assert_equal("RUBY0001 APPEND INBOX {#{mail.size}}\r\n", requests[0])
      assert_equal(mail, received_mail)
      imap.logout
      assert_equal(2, requests.length)
      assert_equal("RUBY0002 LOGOUT\r\n", requests[1])
    ensure
      imap.disconnect if imap
    end
  end

  def test_append_fail
    server = create_tcp_server
    port = server.addr[1]
    mail = <<EOF.gsub(/\n/, "\r\n")
From: shugo@example.com
To: matz@example.com
Subject: hello

hello world
EOF
    requests = []
    start_server do
      sock = server.accept
      begin
        sock.print("* OK test server\r\n")
        requests.push(sock.gets)
        sock.print("RUBY0001 NO Mailbox doesn't exist\r\n")
        requests.push(sock.gets)
        sock.print("* BYE terminating connection\r\n")
        sock.print("RUBY0002 OK LOGOUT completed\r\n")
      ensure
        sock.close
        server.close
      end
    end

    begin
      imap = Net::IMAP.new(server_addr, :port => port)
      assert_raise(Net::IMAP::NoResponseError) do
        imap.append("INBOX", mail)
      end
      assert_equal(1, requests.length)
      assert_equal("RUBY0001 APPEND INBOX {#{mail.size}}\r\n", requests[0])
      imap.logout
      assert_equal(2, requests.length)
      assert_equal("RUBY0002 LOGOUT\r\n", requests[1])
    ensure
      imap.disconnect if imap
    end
  end

  def test_id
    server = create_tcp_server
    port = server.addr[1]
    requests = Queue.new
    server_id = {"name" => "test server", "version" => "v0.1.0"}
    server_id_str = '("name" "test server" "version" "v0.1.0")'
    @threads << Thread.start do
      sock = server.accept
      begin
        sock.print("* OK test server\r\n")
        requests.push(sock.gets)
        # RFC 2971 very clearly states (in section 3.2):
        # "a server MUST send a tagged ID response to an ID command."
        # And yet... some servers report ID capability but won't the response.
        sock.print("RUBY0001 OK ID completed\r\n")
        requests.push(sock.gets)
        sock.print("* ID #{server_id_str}\r\n")
        sock.print("RUBY0002 OK ID completed\r\n")
        requests.push(sock.gets)
        sock.print("* ID #{server_id_str}\r\n")
        sock.print("RUBY0003 OK ID completed\r\n")
        requests.push(sock.gets)
        sock.print("* BYE terminating connection\r\n")
        sock.print("RUBY0004 OK LOGOUT completed\r\n")
      ensure
        sock.close
        server.close
      end
    end

    begin
      imap = Net::IMAP.new(server_addr, :port => port)
      resp = imap.id
      assert_equal(nil, resp)
      assert_equal("RUBY0001 ID NIL\r\n", requests.pop)
      resp = imap.id({})
      assert_equal(server_id, resp)
      assert_equal("RUBY0002 ID ()\r\n", requests.pop)
      resp = imap.id("name" => "test client", "version" => "latest")
      assert_equal(server_id, resp)
      assert_equal("RUBY0003 ID (\"name\" \"test client\" \"version\" \"latest\")\r\n",
                   requests.pop)
      imap.logout
      assert_equal("RUBY0004 LOGOUT\r\n", requests.pop)
    ensure
      imap.disconnect if imap
    end
  end

  test("#authenticate sends an initial response " \
       "when supported by both the mechanism and the server") do
    with_fake_server(
      preauth: false, cleartext_auth: true, sasl_ir: true
    ) do |server, imap|
      imap.authenticate("PLAIN", "test_user", "test-password")
      cmd = server.commands.pop
      assert_equal "AUTHENTICATE", cmd.name
      assert_equal(["PLAIN", ["\x00test_user\x00test-password"].pack("m0")],
                   cmd.args)
      assert_empty server.commands
    end
  end

  test("#authenticate sends '=' as the initial reponse " \
       "when the initial response is an empty string") do
    with_fake_server(
      preauth: false, cleartext_auth: true,
      sasl_ir: true, sasl_mechanisms: %i[EXTERNAL],
    ) do |server, imap|
      server.on "AUTHENTICATE" do |cmd|
        server.state.authenticate(server.config.user)
        cmd.done_ok
      end
      imap.authenticate("EXTERNAL")
      cmd = server.commands.pop
      assert_equal "AUTHENTICATE", cmd.name
      assert_equal %w[EXTERNAL =], cmd.args
      assert_empty server.commands rescue pp server.commands.pop
    end
  end

  test("#authenticate never sends an initial response " \
       "when the server doesn't explicitly support the mechanism") do
    with_fake_server(
      preauth: false, cleartext_auth: true,
      sasl_ir: true, sasl_mechanisms: %i[SCRAM-SHA-1 SCRAM-SHA-256],
    ) do |server, imap|
      imap.authenticate("PLAIN", "test_user", "test-password")
      cmd, cont = 2.times.map { server.commands.pop }
      assert_equal %w[AUTHENTICATE PLAIN], [cmd.name, *cmd.args]
      assert_equal(["\x00test_user\x00test-password"].pack("m0"),
                   cont[:continuation].strip)
      assert_empty server.commands
    end
  end

  test("#authenticate never sends an initial response " \
       "when the server isn't capable") do
    with_fake_server(
      preauth: false, cleartext_auth: true, sasl_ir: false
    ) do |server, imap|
      imap.authenticate("PLAIN", "test_user", "test-password")
      cmd, cont = 2.times.map { server.commands.pop }
      assert_equal %w[AUTHENTICATE PLAIN], [cmd.name, *cmd.args]
      assert_equal(["\x00test_user\x00test-password"].pack("m0"),
                   cont[:continuation].strip)
      assert_empty server.commands
    end
  end

  test("#authenticate never sends an initial response " \
       "when sasl_ir: false") do
    [true, false].each do |server_support|
      with_fake_server(
        preauth: false, cleartext_auth: true, sasl_ir: server_support
      ) do |server, imap|
        imap.authenticate("PLAIN", "test_user", "test-password", sasl_ir: false)
        cmd, cont = 2.times.map { server.commands.pop }
        assert_equal %w[AUTHENTICATE PLAIN], [cmd.name, *cmd.args]
        assert_equal(["\x00test_user\x00test-password"].pack("m0"),
                     cont[:continuation].strip)
        assert_empty server.commands
      end
    end
  end

  test("#authenticate never sends an initial response " \
       "when config.sasl_ir: false") do
    [true, false].each do |server_support|
      with_fake_server(
        preauth: false, cleartext_auth: true, sasl_ir: server_support
      ) do |server, imap|
        imap.config.sasl_ir = false
        imap.authenticate("PLAIN", "test_user", "test-password")
        cmd, cont = 2.times.map { server.commands.pop }
        assert_equal %w[AUTHENTICATE PLAIN], [cmd.name, *cmd.args]
        assert_equal(["\x00test_user\x00test-password"].pack("m0"),
                     cont[:continuation].strip)
        assert_empty server.commands
      end
    end
  end

  test("#authenticate never sends an initial response " \
       "when the mechanism does not support client-first") do
    with_fake_server(
      preauth: false, cleartext_auth: true,
      sasl_ir: true, sasl_mechanisms: %i[DIGEST-MD5]
    ) do |server, imap|
      server.on "AUTHENTICATE" do |cmd|
        response_b64 = cmd.request_continuation(
          [
            %w[
              realm="somerealm"
              nonce="OA6MG9tEQGm2hh"
              qop="auth"
              charset=utf-8
              algorithm=md5-sess
            ].join(",")
          ].pack("m0")
        )
        state.commands << {continuation: response_b64}
        response_b64 = cmd.request_continuation(["rspauth="].pack("m0"))
        state.commands << {continuation: response_b64}
        server.state.authenticate(server.config.user)
        cmd.done_ok
      end
      imap.authenticate(:digest_md5, "test_user", "test-password",
                        warn_deprecation: false)
      cmd, cont1, cont2 = 3.times.map { server.commands.pop }
      assert_equal %w[AUTHENTICATE DIGEST-MD5], [cmd.name, *cmd.args]
      assert_match(%r{\A[a-z0-9+/]+=*\z}i, cont1[:continuation].strip)
      assert_empty cont2[:continuation].strip
      assert_empty server.commands
    end
  end

  test("#authenticate disconnects and raises SASL::AuthenticationFailed " \
       "when the server succeeds prematurely") do
    with_fake_server(
      preauth: false, cleartext_auth: true,
      sasl_ir: true, sasl_mechanisms: %i[DIGEST-MD5]
    ) do |server, imap|
      server.on "AUTHENTICATE" do |cmd|
        response_b64 = cmd.request_continuation(
          [
            %w[
              realm="somerealm"
              nonce="OA6MG9tEQGm2hh"
              qop="auth"
              charset=utf-8
              algorithm=md5-sess
            ].join(",")
          ].pack("m0")
        )
        state.commands << {continuation: response_b64}
        server.state.authenticate(server.config.user)
        cmd.done_ok
      end
      assert_raise(Net::IMAP::SASL::AuthenticationIncomplete) do
        imap.authenticate("DIGEST-MD5", "test_user", "test-password",
                          warn_deprecation: false)
      end
      assert imap.disconnected?
    end
  end

  test "#uid_expunge with EXPUNGE responses" do
    with_fake_server(select: "INBOX",
                     extensions: %i[UIDPLUS]) do |server, imap|
      server.on "UID EXPUNGE" do |resp|
        resp.untagged("1 EXPUNGE")
        resp.untagged("1 EXPUNGE")
        resp.untagged("1 EXPUNGE")
        resp.done_ok
      end
      response = imap.uid_expunge(1000..1003)
      cmd = server.commands.pop
      assert_equal ["UID EXPUNGE", "1000:1003"], [cmd.name, cmd.args]
      assert_equal(response, [1, 1, 1])
    end
  end

  test "#uid_expunge with VANISHED response" do
    with_fake_server(select: "INBOX",
                     extensions: %i[UIDPLUS]) do |server, imap|
      server.on "UID EXPUNGE" do |resp|
        resp.untagged("VANISHED 1001,1003")
        resp.done_ok
      end
      response = imap.uid_expunge(1000..1003)
      cmd = server.commands.pop
      assert_equal ["UID EXPUNGE", "1000:1003"], [cmd.name, cmd.args]
      assert_equal(
        Net::IMAP::VanishedData[uids: [1001, 1003], earlier: false],
        response
      )
      assert_equal([], imap.clear_responses("VANISHED"))
    end
  end

  def test_uidplus_appenduid
    with_fake_server(select: "INBOX",
                     extensions: %i[UIDPLUS]) do |server, imap|
      server.on "APPEND" do |cmd|
        cmd.done_ok code: "APPENDUID 38505 3955"
      end
      resp = imap.append("inbox", <<~EOF.gsub(/\n/, "\r\n"), [:Seen], Time.now)
        Subject: hello
        From: shugo@ruby-lang.org
        To: shugo@ruby-lang.org

        hello world
      EOF
      assert_equal([38505, nil, [3955]], resp.data.code.data.to_a)
      assert_equal "APPEND", server.commands.pop.name
    end
  end

  def test_uidplus_copyuid_multiple
    with_fake_server(select: "INBOX",
                     extensions: %i[UIDPLUS]) do |server, imap|
      server.on "UID COPY" do |cmd|
        cmd.done_ok code: "COPYUID 38505 3955,3960:3962 3963:3966"
      end
      resp = imap.uid_copy([3955,3960..3962], 'trash')
      cmd  = server.commands.pop
      assert_equal(["UID COPY", "3955,3960:3962 trash"], [cmd.name, cmd.args])
      assert_equal(
        [38505, [3955, 3960, 3961, 3962], [3963, 3964, 3965, 3966]],
        resp.data.code.data.to_a
      )
    end
  end

  def test_uidplus_copyuid_single
    with_fake_server(select: "INBOX",
                     extensions: %i[UIDPLUS]) do |server, imap|
      server.on "UID COPY" do |cmd|
        cmd.done_ok code: "COPYUID 38505 3955 3967"
      end
      resp = imap.uid_copy(3955, 'trash')
      cmd  = server.commands.pop
      assert_equal(["UID COPY", "3955 trash"], [cmd.name, cmd.args])
      assert_equal([38505, [3955], [3967]], resp.data.code.data.to_a)
    end
  end

  def test_uidplus_uidnotsticky
    with_fake_server(extensions: %i[UIDPLUS]) do |server, imap|
      server.config.mailboxes["trash"] = { uidnotsticky: true }
      imap.select('trash')
      assert imap.responses("NO", &:to_a).any? {
        _1.code == Net::IMAP::ResponseCode.new('UIDNOTSTICKY', nil)
      }
    end
  end

  def test_enable
    with_fake_server(
      with_extensions: %i[ENABLE CONDSTORE UTF8=ACCEPT],
      capabilities_enablable: %w[CONDSTORE UTF8=ACCEPT]
    ) do |server, imap|
      cmdq = server.commands

      result1 = imap.enable(%w[CONDSTORE x-pig-latin])
      result2 = imap.enable(:utf8, "condstore QResync")
      result3 = imap.enable(:utf8, "UTF8=ACCEPT", "UTF8=ONLY")
      cmd1, cmd2, cmd3 = Array.new(3) { cmdq.pop.raw.strip }

      assert_equal "RUBY0001 ENABLE CONDSTORE x-pig-latin",         cmd1
      assert_equal "RUBY0002 ENABLE UTF8=ACCEPT condstore QResync", cmd2
      assert_equal "RUBY0003 ENABLE UTF8=ACCEPT",                   cmd3
      assert_empty cmdq

      assert_equal %w[CONDSTORE],   result1
      assert_equal %w[UTF8=ACCEPT], result2
      assert_equal [],              result3
    end
  end

  test "#select with condstore" do
    with_fake_server do |server, imap|
      imap.select "inbox", condstore: true
      assert_equal("RUBY0001 SELECT inbox (CONDSTORE)",
                   server.commands.pop.raw.strip)
    end
  end

  test "#examine with condstore" do
    with_fake_server do |server, imap|
      imap.examine "inbox", condstore: true
      assert_equal("RUBY0001 EXAMINE inbox (CONDSTORE)",
                   server.commands.pop.raw.strip)
    end
  end

  test "#fetch with changedsince" do
    with_fake_server select: "inbox" do |server, imap|
      server.on("FETCH", &:done_ok)
      imap.fetch 1..-1, %w[FLAGS], changedsince: 12345
      assert_equal("RUBY0002 FETCH 1:* (FLAGS) (CHANGEDSINCE 12345)",
                   server.commands.pop.raw.strip)
    end
  end

  test "#uid_fetch with changedsince" do
    with_fake_server select: "inbox" do |server, imap|
      server.on("UID FETCH", &:done_ok)
      imap.uid_fetch 1..-1, %w[FLAGS], changedsince: 12345
      assert_equal("RUBY0002 UID FETCH 1:* (FLAGS) (CHANGEDSINCE 12345)",
                   server.commands.pop.raw.strip)
    end
  end

  test "#store with unchangedsince" do
    with_fake_server select: "inbox" do |server, imap|
      server.on("STORE", &:done_ok)
      imap.store 1..-1, "FLAGS", %i[Deleted], unchangedsince: 12345
      assert_equal(
        "RUBY0002 STORE 1:* (UNCHANGEDSINCE 12345) FLAGS (\\Deleted)",
        server.commands.pop.raw.strip
      )
    end
  end

  test "#uid_store with changedsince" do
    with_fake_server select: "inbox" do |server, imap|
      server.on("UID STORE", &:done_ok)
      imap.uid_store 1..-1, "FLAGS", %i[Deleted], unchangedsince: 987
      assert_equal(
        "RUBY0002 UID STORE 1:* (UNCHANGEDSINCE 987) FLAGS (\\Deleted)",
        server.commands.pop.raw.strip
      )
    end
  end

  test "#expunge with EXPUNGE responses" do
    with_fake_server(select: "INBOX") do |server, imap|
      server.on "EXPUNGE" do |resp|
        resp.untagged("1 EXPUNGE")
        resp.untagged("1 EXPUNGE")
        resp.untagged("99 EXPUNGE")
        resp.done_ok
      end
      response = imap.expunge
      cmd = server.commands.pop
      assert_equal ["EXPUNGE", nil], [cmd.name, cmd.args]
      assert_equal [1, 1, 99], response
      assert_equal [], imap.clear_responses("EXPUNGED")
    end
  end

  test "#expunge with a VANISHED response" do
    with_fake_server(select: "INBOX") do |server, imap|
      server.on "EXPUNGE" do |resp|
        resp.untagged("VANISHED 15:456")
        resp.done_ok
      end
      response = imap.expunge
      cmd = server.commands.pop
      assert_equal ["EXPUNGE", nil], [cmd.name, cmd.args]
      assert_equal(
        Net::IMAP::VanishedData[uids: [15..456], earlier: false],
        response
      )
      assert_equal([], imap.clear_responses("VANISHED"))
    end
  end

  test "#expunge with multiple VANISHED responses" do
    with_fake_server(select: "INBOX") do |server, imap|
      server.unsolicited("VANISHED 86")
      server.on "EXPUNGE" do |resp|
        resp.untagged("VANISHED (EARLIER) 1:5,99,123")
        resp.untagged("VANISHED 15,456")
        resp.untagged("VANISHED (EARLIER) 987,1001")
        resp.done_ok
      end
      response = imap.expunge
      cmd = server.commands.pop
      assert_equal ["EXPUNGE", nil], [cmd.name, cmd.args]
      assert_equal(
        Net::IMAP::VanishedData[uids: [15, 86, 456], earlier: false],
        response
      )
      assert_equal(
        [
          Net::IMAP::VanishedData[uids: [1..5, 99, 123], earlier: true],
          Net::IMAP::VanishedData[uids: [987, 1001],     earlier: true],
        ],
        imap.clear_responses("VANISHED")
      )
    end
  end

  def test_close
    with_fake_server(select: "inbox") do |server, imap|
      resp = imap.close
      assert_equal("RUBY0002 CLOSE", server.commands.pop.raw.strip)
      assert_equal([Net::IMAP::TaggedResponse, "RUBY0002", "OK"],
                   [resp.class, resp.tag, resp.name])
      assert_empty server.commands
    end
  end

  def test_unselect
    with_fake_server(select: "inbox") do |server, imap|
      resp = imap.unselect
      sent = server.commands.pop
      assert_equal(["UNSELECT", nil], [sent.name, sent.args])
      assert_equal([Net::IMAP::TaggedResponse, "RUBY0002", "OK"],
                   [resp.class, resp.tag, resp.name])
      assert_empty server.commands
    end
  end

  test("missing server ENABLED response") do
    with_fake_server do |server, imap|
      server.on "ENABLE", &:done_ok
      enabled = imap.enable "foo", "bar", "baz"
      assert_equal [], enabled
    end
  end

  test("#search/#uid_search") do
    with_fake_server do |server, imap|
      search_result = Net::IMAP::SearchResult[
        1, 2, 3, 5, 8, 13, 21, 34, 55, modseq: 1234
      ]
      search_resp = ->cmd do
        cmd.puts search_result.to_s("SEARCH")
        cmd.done_ok
      end

      server.on "SEARCH", &search_resp
      assert_equal search_result, imap.search(["subject", "hello world",
                                               [1..5, 8, 10..-1]])
      cmd = server.commands.pop
      assert_equal(
        ["SEARCH",'subject "hello world" 1:5,8,10:*'],
        [cmd.name, cmd.args]
      )

      imap.search(["OR", 1..1000, -1, "UID", 12345..-1])
      assert_equal "OR 1:1000 * UID 12345:*", server.commands.pop.args

      imap.search([1..1000, "UID", 12345..])
      assert_equal "1:1000 UID 12345:*", server.commands.pop.args

      # Unfortunately, we can't send every sequence-set string directly
      imap.search(["SUBJECT", "1,*"])
      assert_equal 'SUBJECT "1,*"', server.commands.pop.args

      imap.search(["subject", "hello", Set[1, 2, 3, 4, 5, 8, *(10..100)]])
      assert_equal "subject hello 1:5,8,10:100", server.commands.pop.args

      imap.search('SUBJECT "Hello world"', "UTF-8")
      assert_equal 'CHARSET UTF-8 SUBJECT "Hello world"', server.commands.pop.args

      imap.search('CHARSET UTF-8 SUBJECT "Hello world"')
      assert_equal 'CHARSET UTF-8 SUBJECT "Hello world"', server.commands.pop.args

      imap.search('SUBJECT "Hello world"', charset: "UTF-8")
      assert_equal 'CHARSET UTF-8 SUBJECT "Hello world"', server.commands.pop.args

      imap.search([:*])
      assert_equal "*", server.commands.pop.args

      seqset_coercible = Object.new
      def seqset_coercible.to_sequence_set
        Net::IMAP::SequenceSet[1..9]
      end
      imap.search([seqset_coercible])
      assert_equal "1:9", server.commands.pop.args

      server.on "UID SEARCH", &search_resp
      assert_equal search_result, imap.uid_search(["subject", "hello",
                                                   [1..22, 30..-1]])
      cmd = server.commands.pop
      assert_equal ["UID SEARCH", "subject hello 1:22,30:*"], [cmd.name, cmd.args]

      assert_equal search_result, imap.search(
        "RETURN (COUNT) NOT (FLAGGED (OR SEEN ANSWERED))"
      )
      cmd = server.commands.pop
      assert_equal "RETURN (COUNT) NOT (FLAGGED (OR SEEN ANSWERED))", cmd.args

      assert_equal search_result, imap.search([
        "RETURN", %w(MIN MAX COUNT), "NOT", ["FLAGGED", %w(OR SEEN ANSWERED)]
      ])
      cmd = server.commands.pop
      assert_equal "RETURN (MIN MAX COUNT) NOT (FLAGGED (OR SEEN ANSWERED))", cmd.args

      assert_equal search_result, imap.search(
        ["NOT", ["FLAGGED", %w(OR SEEN ANSWERED)]], return: %w(MIN MAX COUNT)
      )
      cmd = server.commands.pop
      assert_equal "RETURN (MIN MAX COUNT) NOT (FLAGGED (OR SEEN ANSWERED))", cmd.args

      assert_equal search_result, imap.search(
        ["UID", 1234..], return: %w(PARTIAL -500:-1)
      )
      cmd = server.commands.pop
      assert_equal "RETURN (PARTIAL -500:-1) UID 1234:*", cmd.args

      assert_equal search_result, imap.search(
        ["UID", 1234..], return: [:PARTIAL, "-500:-1"]
      )
      cmd = server.commands.pop
      assert_equal "RETURN (PARTIAL -500:-1) UID 1234:*", cmd.args

      assert_equal search_result, imap.search(
        ["UID", 1234..], return: [:PARTIAL, -500..-1, :FOO, 1..]
      )
      cmd = server.commands.pop
      assert_equal "RETURN (PARTIAL -500:-1 FOO 1:*) UID 1234:*", cmd.args
    end
  end

  test("#search/#uid_search with invalid arguments") do
    with_fake_server do |server, imap|
      server.on "SEARCH"     do |cmd| cmd.fail_no "should fail before this" end
      server.on "UID SEARCH" do |cmd| cmd.fail_no "should fail before this" end

      assert_raise(ArgumentError) do
        imap.search(["charset", "foo", "ALL"], "bar")
      end
      assert_raise(ArgumentError) do
        imap.search("charset foo ALL", "bar")
      end
      assert_raise(ArgumentError) do
        imap.search(["ALL"], "foo", charset: "bar")
      end
      assert_raise(ArgumentError) do
        imap.search(["charset", "foo", "ALL"], charset: "bar")
      end
      assert_raise(ArgumentError) do
        imap.search("charset foo ALL", charset: "bar")
      end
      # Parsing return opts is too complicated, for now.
      # assert_raise(ArgumentError) do
      #   imap.search("return () charset foo ALL", "bar")
      # end

      assert_raise(ArgumentError) do
        imap.search(["retURN", %w(foo bar), "ALL"], return: %w[foo bar])
      end
      assert_raise(ArgumentError) do
        imap.search("RETURN (foo bar) ALL", return: %w[foo bar])
      end
      assert_raise(TypeError) do
        imap.search("ALL", return: "foo bar")
      end
      assert_raise(TypeError) do
        imap.search(["retURN", "foo bar", "ALL"])
      end
    end
  end

  test("#search/#uid_search with ESEARCH or IMAP4rev2") do
    with_fake_server do |server, imap|
      # Example from RFC9051, 6.4.4:
      #   C: A282 SEARCH RETURN (MIN COUNT) FLAGGED
      #       SINCE 1-Feb-1994 NOT FROM "Smith"
      #   S: * ESEARCH (TAG "A282") MIN 2 COUNT 3
      #   S: A282 OK SEARCH completed
      server.on "SEARCH" do |cmd|
        cmd.untagged "ESEARCH", "(TAG \"unrelated1\") MIN 1 COUNT 2"
        cmd.untagged "ESEARCH", "(TAG %p) MIN 2 COUNT 3" % [cmd.tag]
        cmd.untagged "ESEARCH", "(TAG \"unrelated2\") MIN 222 COUNT 333"
        cmd.done_ok
      end
      result = imap.search(
        'RETURN (MIN COUNT) FLAGGED SINCE 1-Feb-1994 NOT FROM "Smith"'
      )
      cmd = server.commands.pop
      assert_equal Net::IMAP::ESearchResult.new(
        cmd.tag, false, [["MIN", 2], ["COUNT", 3]]
      ), result
      esearch_responses = imap.clear_responses("ESEARCH")
      assert_equal 2, esearch_responses.count
      refute esearch_responses.include?(result)
    end
  end

  test("missing server ESEARCH response") do
    with_fake_server do |server, imap|
      # Example from RFC9051, 6.4.4:
      #   C: A282 SEARCH RETURN (SAVE) FLAGGED SINCE 1-Feb-1994 NOT FROM "Smith"
      #   S: A282 OK SEARCH completed, result saved
      server.on "SEARCH"     do |cmd| cmd.done_ok "result saved" end
      server.on "UID SEARCH" do |cmd| cmd.done_ok "result saved" end
      result = imap.search(
        'RETURN (SAVE) FLAGGED SINCE 1-Feb-1994 NOT FROM "Smith"'
      )
      assert_pattern do
        result => Net::IMAP::ESearchResult[uid: false, tag: /^RUBY\d+/, data: []]
      end
      result = imap.uid_search(
        'RETURN (SAVE) FLAGGED SINCE 1-Feb-1994 NOT FROM "Smith"'
      )
      assert_pattern do
        result => Net::IMAP::ESearchResult[uid: true, tag: /^RUBY\d+/, data: []]
      end
    end
  end

  test("missing server SEARCH response") do
    with_fake_server do |server, imap|
      server.on "SEARCH",     &:done_ok
      server.on "UID SEARCH", &:done_ok
      found = imap.search ["subject", "hello"]
      assert_instance_of Net::IMAP::SearchResult, found
      assert_empty found
      found = imap.uid_search ["subject", "hello"]
      assert_instance_of Net::IMAP::SearchResult, found
      assert_empty found
    end
  end

  test("missing server SORT response") do
    with_fake_server do |server, imap|
      server.on "SORT",       &:done_ok
      server.on "UID SORT",   &:done_ok
      found = imap.sort ["INTERNALDATE"], ["subject", "hello"], "UTF-8"
      assert_equal [], found
      found = imap.uid_sort ["INTERNALDATE"], ["subject", "hello"], "UTF-8"
      assert_equal [], found
    end
  end

  test("missing server THREAD response") do
    with_fake_server do |server, imap|
      server.on "THREAD",     &:done_ok
      server.on "UID THREAD", &:done_ok
      found = imap.thread "REFERENCES", ["subject", "hello"], "UTF-8"
      assert_equal [], found
      found = imap.uid_thread "REFERENCES", ["subject", "hello"], "UTF-8"
      assert_equal [], found
    end
  end

  private

  def imaps_test(timeout: 10)
    Timeout.timeout(timeout) do
      server = create_tcp_server
      port = server.addr[1]
      ctx = OpenSSL::SSL::SSLContext.new
      ctx.ca_file = CA_FILE
      ctx.key = File.open(SERVER_KEY) { |f|
        OpenSSL::PKey::RSA.new(f)
      }
      ctx.cert = File.open(SERVER_CERT) { |f|
        OpenSSL::X509::Certificate.new(f)
      }
      ssl_server = OpenSSL::SSL::SSLServer.new(server, ctx)
      started = false
      ths = Thread.start do
        Thread.current.report_on_exception = false # always join-ed
        begin
          started = true
          sock = ssl_server.accept
          begin
            sock.print("* OK test server\r\n")
            sock.gets
            sock.print("* BYE terminating connection\r\n")
            sock.print("RUBY0001 OK LOGOUT completed\r\n")
          ensure
            sock.close
          end
        rescue Errno::EPIPE, Errno::ECONNRESET, Errno::ECONNABORTED
        end
      end
      sleep 0.1 until started
      begin
        begin
          imap = yield(port)
          imap.logout
          imap
        ensure
          imap.disconnect if imap
        end
      ensure
        ssl_server.close
        ths.join
      end
    end
  end

  def starttls_test
    server = create_tcp_server
    port = server.addr[1]
    start_server do
      sock = server.accept
      begin
        sock.print("* OK test server\r\n")
        sock.gets
        sock.print("RUBY0001 OK completed\r\n")
        ctx = OpenSSL::SSL::SSLContext.new
        ctx.ca_file = CA_FILE
        ctx.key = File.open(SERVER_KEY) { |f|
          OpenSSL::PKey::RSA.new(f)
        }
        ctx.cert = File.open(SERVER_CERT) { |f|
          OpenSSL::X509::Certificate.new(f)
        }
        sock = OpenSSL::SSL::SSLSocket.new(sock, ctx)
        sock.sync_close = true
        sock.accept
        sock.gets
        sock.print("* BYE terminating connection\r\n")
        sock.print("RUBY0002 OK LOGOUT completed\r\n")
      rescue OpenSSL::SSL::SSLError
      ensure
        sock.close
        server.close
      end
    end
    begin
      imap = yield(port)
      imap.logout if !imap.disconnected?
    ensure
      imap.disconnect if imap && !imap.disconnected?
    end
  end

  def starttls_stripping_test
    server = create_tcp_server
    port = server.addr[1]
    start_server do
      sock = server.accept
      begin
        sock.print("* OK test server\r\n")
        sock.gets
        sock.print("RUBY0001 BUG unhandled command\r\n")
      ensure
        sock.close
        server.close
      end
    end
    begin
      imap = yield(port)
    ensure
      imap.disconnect if imap && !imap.disconnected?
    end
  end

  def create_tcp_server
    return TCPServer.new(server_addr, 0)
  end

  def server_addr
    Addrinfo.tcp("localhost", 0).ip_address
  end

end
