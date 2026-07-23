# frozen_string_literal: true

require "net/imap"
require "test/unit"
require_relative "fake_server"

class IMAPTest < Net::IMAP::TestCase
  CA_FILE = File.expand_path("../fixtures/cacert.pem", __dir__)
  SERVER_KEY = File.expand_path("../fixtures/server.key", __dir__)
  SERVER_CERT = File.expand_path("../fixtures/server.crt", __dir__)

  include Net::IMAP::FakeServer::TestHelper

  if defined?(OpenSSL::SSL::SSLError)
    def test_imaps_unknown_ca
      assert_local_raise(OpenSSL::SSL::SSLError) do
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
        begin
          imaps_test do |port|
            imap = Net::IMAP.new("localhost",
                                port: port,
                                ssl: { :ca_file => CA_FILE })
            verified = imap.tls_verified?
            imap
          rescue SystemCallError
            skip $!
          end
        rescue OpenSSL::SSL::SSLError => e
          raise e unless /darwin/ =~ RUBY_PLATFORM
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
        begin
          imaps_test do |port|
            imap = Net::IMAP.new(
              server_addr,
              port: port,
              ssl: { :verify_mode => OpenSSL::SSL::VERIFY_NONE }
            )
            verified = imap.tls_verified?
            imap
          end
        rescue OpenSSL::SSL::SSLError => e
          raise e unless /darwin/ =~ RUBY_PLATFORM
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
      assert_local_raise(OpenSSL::SSL::SSLError) do
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
      ex = nil
      starttls_test do |port|
        imap = Net::IMAP.new("localhost", port: port)
        begin
          imap.starttls
        rescue => ex
        end
        imap
      end
      assert_kind_of(OpenSSL::SSL::SSLError, ex)
      assert_equal (stack = caller), ex.backtrace&.last(stack.size)
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
      assert_equal true,  imap.tls_verified?
      assert_include imap.inspect, " TLS disconnected"
      assert_equal({ca_file: CA_FILE}, imap.ssl_ctx_params)
    rescue SystemCallError
      skip $!
    ensure
      if imap && !imap.disconnected?
        imap.disconnect
      end
    end

    def test_starttls_stripping_not_ok
      imap = nil
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
        imap = Net::IMAP.new("localhost", :port => port)
        assert_reraised(Net::IMAP::InvalidResponseError, imap:) do
          imap.starttls(:ca_file => CA_FILE)
        end
        assert imap.disconnected?
      ensure
        imap.disconnect if imap && !imap.disconnected?
      end

      assert_equal false, imap.tls_verified?
      assert_include imap.inspect, " PLAINTEXT (TLS NOT STARTED) "
      assert_equal({ca_file: CA_FILE},        imap.ssl_ctx_params)
      assert_equal(CA_FILE,                   imap.ssl_ctx.ca_file)
      assert_equal(OpenSSL::SSL::VERIFY_PEER, imap.ssl_ctx.verify_mode)
    end

    def test_starttls_stripping_ok_sent_before_response
      # to coordinate between threads (better than sleep)
      server_to_client, client_to_server = Queue.new, Queue.new
      rcvr_to_client = Queue.new
      imap = nil
      server = create_tcp_server
      port = server.addr[1]
      start_server do
        sock = server.accept
        begin
          sock.print("* OK test server\r\n")
          assert_equal :send_malicious_response, client_to_server.pop
          sock.print("RUBY0001 OK hahaha, fooled you!\r\n")
          server_to_client << :malicious_response_sent
          sock.gets
        ensure
          sock.close
          server.close
        end
      end
      timeout = 5
      timeout *= EnvUtil.timeout_scale || 1 if defined?(EnvUtil.timeout_scale)
      begin
        Timeout.timeout(timeout) do
          imap = Net::IMAP.new("localhost", :port => port)
          imap.add_response_handler do |resp| rcvr_to_client << resp end
          client_to_server << :send_malicious_response
          assert_equal :malicious_response_sent, server_to_client.pop
          # Wait until the receive thread has parsed the injected response and
          # stored it in @tagged_responses, so finish_sending_command can see it.
          # (handle_response stores the tagged response before calling handlers.)
          rcvr_to_client.pop
          assert_local_raise(Net::IMAP::InvalidTaggedResponseError) do
            imap.starttls(:ca_file => CA_FILE)
          end
          assert imap.disconnected?
        end
      ensure
        imap.disconnect if imap && !imap.disconnected?
      end
      assert_equal false, imap.tls_verified?
      assert_include imap.inspect, " PLAINTEXT (TLS NOT STARTED) "
      assert_equal({ca_file: CA_FILE},        imap.ssl_ctx_params)
      assert_equal(CA_FILE,                   imap.ssl_ctx.ca_file)
      assert_equal(OpenSSL::SSL::VERIFY_PEER, imap.ssl_ctx.verify_mode)
    end
  end

  # Similar to STARTTLS stripping test, but checks other commands too
  data(
    "IDLE"   => ->imap do imap.idle(1) do end end,
    "NOOP"   => ->imap do imap.noop end,
    "SELECT" => ->imap do imap.select("inbox") end,
  )
  test "premature tagged OK response" do |cmd|
    timeout = 5
    timeout *= EnvUtil.timeout_scale || 1 if defined?(EnvUtil.timeout_scale)
    Timeout.timeout(timeout) do
      server_to_client = Queue.new
      client_to_server = Queue.new
      rcvr_to_client   = Queue.new
      server = create_tcp_server
      port = server.addr[1]
      start_server do
        sock = server.accept
        begin
          sock.print("* OK test server\r\n")
          assert_equal :send_malicious_responses, client_to_server.pop
          sock.print("RUBY0001 OK invalid\r\n")
          sock.print("RUBY0002 OK false\r\n")
          sock.print("RUBY0003 OK tricky\r\n")
          server_to_client << :sent_malicious_responses
          sock.gets
        ensure
          sock.close
          server.close
        end
      end
      begin
        imap = Net::IMAP.new(server_addr, port:)
        i = 0
        imap.add_response_handler do |resp|
          rcvr_to_client << (i += 1)
        end
        client_to_server << :send_malicious_responses
        assert_equal :sent_malicious_responses, server_to_client.pop
        assert_equal [1, 2, 3], 3.times.map { rcvr_to_client.pop }
        # should respond this way for _any_ command
        assert_local_raise(Net::IMAP::InvalidTaggedResponseError) do
          cmd.(imap)
        end
        assert imap.disconnected?
        assert_stream_closed_error do cmd.(imap) end
        assert_stream_closed_error do cmd.(imap) end
        assert_stream_closed_error do cmd.(imap) end
      ensure
        imap.disconnect if imap
      end
    end
  end

  def start_server
    th = Thread.new do
      yield
    end
    @threads << th
    sleep 0.001 until th.stop?
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
      assert_local_raise EOFError do
        imap.logout
      end
    ensure
      imap.disconnect if imap
    end
  end

  BrokenResponseReaderTestError = Class.new(StandardError)

  test "exception from response reader" do
    with_fake_server ignore_io_error: true, ignore_abrupt_eof: true do |server, imap|
      handler = imap.add_response_handler do
        imap.instance_exec do
          def @reader.read_response_buffer
            raise BrokenResponseReaderTestError, "testing"
          end
        end
        imap.remove_response_handler handler
      end
      server.unsolicited "OK [ALERT] trigger read_response_buffer switcheroo"
      server.unsolicited "OK [ALERT] trigger reader error"
      # NOTE: closing the socket happens in the receiver thread, creating a race
      # condition if a client thread issues a command right *here*.
      #
      # If a command is called here, it may run before or after the response
      # reader error closes the connection.  If it runs before, then
      # `get_tagged_response` should return the BrokenResponseReaderTestError
      # exception.  If it runs after, we'll see the "stream closed" IOError.
      #
      # The distinction between these errors is not considered important enough
      # to justify delaying for the "correct" error or complex tests to capture
      # each possible case.
      #
      # By waiting for the receiver thread to close, this test ensures a stable
      # result: the socket will be closed and `@exception` will be assigned...
      # But, since `send_command` doesn't currently check this before attempting
      # to send, it simply raises the "stream closed" IOError.
      wait_for_receiver_thread_terminating(imap)

      assert imap.disconnected?
      assert_stream_closed_error do
        imap.noop
      end
      assert imap.disconnected?
    end
  end

  test "exception from response parser" do
    with_fake_server ignore_io_error: true, ignore_abrupt_eof: true do |server, imap|
      server.on "NOOP" do |resp|
        resp.puts "#{resp.tag} NOPE [SERVERBUG] this ain't right!"
      end
      assert_reraised(Net::IMAP::InvalidResponseError, /bad.*NOPE/, imap:) do
        imap.noop
      end
      assert imap.disconnected?
    end
    with_fake_server ignore_abrupt_eof: true do |server, imap|
      server.on "FETCH" do |resp|
        resp.untagged '1 FETCH (BODY[] ")'
        resp.done_ok
      end
      assert_reraised(Net::IMAP::ResponseParseError, imap:) do
        imap.fetch 1, "FAST"
      end
      assert imap.disconnected?
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
      assert_local_raise(Net::IMAP::Error) do
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
      assert_local_raise(Net::IMAP::ByeResponseError) do
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
      assert_local_raise(RuntimeError) do
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
    sleep 0.001 until started
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
        assert_local_raise(EOFError) do
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
    assert_local_raise(Net::IMAP::Error) do
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

  def test_send_integer
    with_fake_server do |server, imap|
      server.on "TEST", &:done_ok

      # regular numbers may be any uint32
      assert_raise(Net::IMAP::DataFormatError) do
        imap.__send__(:send_command, "TEST", -1)
      end
      assert_empty server.commands

      imap.__send__(:send_command, "TEST", 0)
      assert_equal "0", server.commands.pop.args

      imap.__send__(:send_command, "TEST", 2**32 - 1)
      assert_equal (2**32 - 1).to_s, server.commands.pop.args

      imap.__send__(:send_command, "TEST", 2**32)
      assert_equal (2**32).to_s, server.commands.pop.args

      imap.__send__(:send_command, "TEST", 2**64 - 1)
      assert_equal (2**64 - 1).to_s, server.commands.pop.args

      assert_raise(Net::IMAP::DataFormatError) do
        imap.__send__(:send_command, "TEST", 2**64)
      end
      assert_empty server.commands
    end
  end

  def test_send_sequence_set
    with_fake_server do |server, imap|
      server.on "TEST", &:done_ok

      # SequenceSet numbers may be non-zero uint3, and -1 is translated to *
      imap.__send__(:send_command, "TEST", Net::IMAP::SequenceSet.new(-1))
      assert_equal "*", server.commands.pop.args

      assert_raise(Net::IMAP::DataFormatError) do
        imap.__send__(:send_command, "TEST", Net::IMAP::SequenceSet.new(0))
      end
      assert_empty server.commands

      imap.__send__(:send_command, "TEST", Net::IMAP::SequenceSet.new(1))
      assert_equal "1", server.commands.pop.args

      imap.__send__(:send_command, "TEST", Net::IMAP::SequenceSet.new(2**32-1))
      assert_equal (2**32 - 1).to_s, server.commands.pop.args

      assert_raise(Net::IMAP::DataFormatError) do
        imap.__send__(:send_command, "TEST", Net::IMAP::SequenceSet.new(2**32))
      end
      assert_empty server.commands
    end
  end

  def test_send_symbol_as_flag
    with_fake_server do |server, imap|
      server.on "TEST", &:done_ok

      imap.__send__(:send_command, "TEST", :Seen, :Flagged)
      assert_equal "\\Seen \\Flagged", server.commands.pop.args

      # symbol may not contain atom-specials
      [
        :"with_parens()",
        :"with_list_wildcards*",
        :"with_list_wildcards%",
        :"with_resp_special]",
        :"with\0null",
        :"with\x7fcontrol_char",
        :'"with_quoted_specials"',
        :"with_quoted_specials\\",
        :"with\rCR",
        :"with\nLF",
      ].each do |symbol|
        assert_raise_with_message(Net::IMAP::DataFormatError, /\bflag\b/i) do
          imap.__send__(:send_command, "TEST", symbol)
        end
        assert_empty server.commands
      end
    end
  end

  def test_raw_data
    with_fake_server do |server, imap|
      server.on "TEST", &:done_ok

      imap.__send__(:send_command, "TEST", Net::IMAP::RawData.new("foo bar"))
      assert_equal "foo bar", server.commands.pop.args

      imap.__send__(:send_command, "TEST",
                    Net::IMAP::RawData.new("{3}\r\nfoo"),
                    Net::IMAP::RawData.new("~{4}\r\n\0bar"))
      assert_equal "{3}\r\nfoo ~{4}\r\n\0bar", server.commands.pop.args

      # RawData must pass basic validation before sending command
      [
        "with \0 NULL",
        "with \r CR",
        "with \n LF",
        "with \r\n CRLF",
        "{1234}\r\nliteral is too small",
        "{1}\r\n\0 literal contains NULL",
      ].each do |data|
        assert_raise(Net::IMAP::DataFormatError) do
          imap.__send__(:send_command, "TEST", Net::IMAP::RawData[data:])
        end
        assert_empty server.commands
      end
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

  test "sending nil args" do
    with_fake_server do |server, imap|
      server.on "TEST", &:done_ok
      def imap.test_args(*args) = send_command("TEST", *args)

      imap.test_args nil, [nil]
      assert_equal "NIL (NIL)", server.commands.pop.args
    end
  end

  test "sending atom string args (astring-chars)" do
    with_fake_server do |server, imap|
      server.on "TEST", &:done_ok
      def imap.test_args(*args) = send_command("TEST", *args)

      imap.test_args "valid-atoms", %w[foo=bar $baz]
      assert_equal "valid-atoms (foo=bar $baz)", server.commands.pop.args

      imap.test_args "unquoted-astring", "[resp-specials]"
      assert_equal "unquoted-astring [resp-specials]", server.commands.pop.args
    end
  end

  test "string args don't allow NULL bytes" do
    with_fake_server do |server, imap|
      server.on "TEST", &:done_ok
      def imap.test_args(*args) = send_command("TEST", *args)

      assert_raise_with_message(Net::IMAP::DataFormatError, /NULL byte/) do
        imap.test_args "NULL=\0"
      end

      assert_raise_with_message(Net::IMAP::DataFormatError, /NULL byte/) do
        imap.test_args ["ok", "also ok", "not ok: \0"]
      end
    end
  end

  test "sending quoted string args" do
    with_fake_server do |server, imap|
      server.on "TEST", &:done_ok
      def imap.test_args(*args) = send_command("TEST", *args)

      imap.test_args "empty", "", [""]
      assert_equal   'empty "" ("")', server.commands.pop.args

      imap.test_args "simple-quotable-specials", "() {} %*"
      assert_equal('simple-quotable-specials "() {} %*"'.b,
                   server.commands.pop.args)

      imap.test_args "ascii-ctrl-chars", "\b\x7f"
      assert_equal("ascii-ctrl-chars \"\b\x7f\"".b, server.commands.pop.args)

      imap.test_args "quoted-specials", ["backslash=\\", 'dquotes=""']
      assert_equal('quoted-specials ("backslash=\\\\" "dquotes=\\"\\"")'.b,
                   server.commands.pop.args)
    end
  end

  test "sending UTF-8 string args" do
    with_fake_server(
      with_extensions: %w[UTF8=ACCEPT LITERAL-],
      greeting_capabilities: true,
      capabilities_enablable: %w[UTF8=ACCEPT],
    ) do |server, imap|
      server.on "TEST", &:done_ok
      def imap.test_args(*args) = send_command("TEST", *args)

      # Before enabling UTF-8 strings, with non-synchronizing literals
      imap.test_args "sync-literal-utf8", ["αβγδε"]
      assert_equal("sync-literal-utf8 ({10+}\r\nαβγδε)".b,
                   server.commands.pop.args)

      imap.test_args "utf8-with-wrong-encoding", "αβγδε".b
      assert_equal("utf8-with-wrong-encoding {10+}\r\nαβγδε".b,
                   server.commands.pop.args)

      imap.test_args "invalid-utf8", "\x80".b.force_encoding("UTF-8")
      assert_equal("invalid-utf8 {1+}\r\n\x80".b,
                   server.commands.pop.args)

      # Before enabling UTF-8 strings, without non-synchronizing literals
      imap.config.max_non_synchronizing_literal = -1
      imap.test_args "sync-literal-utf8", ["αβγδε"]
      assert_equal("sync-literal-utf8 ({10}\r\nαβγδε)".b,
                   server.commands.pop.args)

      imap.test_args "utf8-with-wrong-encoding", "αβγδε".b
      assert_equal("utf8-with-wrong-encoding {10}\r\nαβγδε".b,
                   server.commands.pop.args)

      imap.test_args "invalid-utf8", "\x80".b.force_encoding("UTF-8")
      assert_equal("invalid-utf8 {1}\r\n\x80".b,
                   server.commands.pop.args)

      # After enabling UTF-8 strings
      imap.enable(:utf8)
      assert imap.utf8_enabled?
      server.commands.pop.args => ["UTF8=ACCEPT"]

      imap.test_args "quoted-utf8", "αβγδε"
      assert_equal 'quoted-utf8 "αβγδε"'.b, server.commands.pop.args

      imap.test_args "utf8-with-wrong-encoding", "αβγδε".b
      assert_equal("utf8-with-wrong-encoding {10}\r\nαβγδε".b,
                   server.commands.pop.args)

      imap.test_args "invalid-utf8", "\x80".b.force_encoding("UTF-8")
      assert_equal("invalid-utf8 {1}\r\n\x80".b,
                   server.commands.pop.args)
    end
  end

  test("send literal args") do
    with_fake_server(with_extensions: %w[LITERAL-]) do |server, imap|
      # disable automatic non-synchronizing literals
      imap.config.max_non_synchronizing_literal = -1
      server.on "TEST", &:done_ok
      send_args = ->(*args) do
        imap.__send__(:send_command, "TEST", *args)
      end
      send_args.call ["\xDE\xAD\xBE\xEF".b]
      assert_equal "({4}\r\n\xDE\xAD\xBE\xEF)".b, server.commands.pop.args

      send_args.call ["hi\rthere\n", "huh?\r\nfake out"]
      assert_equal "({9}\r\nhi\rthere\n {14}\r\nhuh?\r\nfake out)".b,
                   server.commands.pop.args

      # enable automatic non-synchronizing literals
      imap.config.max_non_synchronizing_literal = 1024
      buff = bytes = nil
      server.literal_acceptor = proc { buff, bytes = _1, _2; false }
      server.on "TEST", &:done_ok
      send_args = ->(*args) do
        imap.__send__(:send_command, "TEST", *args)
      end
      send_args.call ["\xDE\xAD\xBE\xEF".b]
      assert_equal "({4+}\r\n\xDE\xAD\xBE\xEF)".b, server.commands.pop.args
      assert_nil buff
      assert_nil bytes

      # limited automatic non-synchronizing literals
      imap.config.max_non_synchronizing_literal = 5
      assert_local_raise(Net::IMAP::NoResponseError) do
        send_args.call [
          Net::IMAP::Literal["\rhi\r"],
          Net::IMAP::Literal["\x01" * 10],
        ]
      end
      assert_match(/TEST \(\{4\+\}\r\n\rhi\r \{10\}\r\n\z/, buff)
      assert_equal 10, bytes
      assert_empty server.commands

      server.literal_acceptor = proc { true }
      send_args.call Net::IMAP::Literal["\x01" * 10]
      assert_equal "{10}\r\n\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01",
        server.commands.pop.args

      buff = bytes = nil
      server.literal_acceptor = proc { buff, bytes = _1, _2; false }
      send_args.call("nonsync",
                     Net::IMAP::Literal[data: "\x01\x02\x03", non_sync: true])
      assert_equal "nonsync {3+}\r\n\x01\x02\03".b, server.commands.pop.args
      assert_nil buff
      assert_nil bytes

      imap.config.max_non_synchronizing_literal = 5
      server.literal_acceptor = proc { true }
      send_args.call("literal",   Net::IMAP::Literal["\r",       false],
                     "literal",   Net::IMAP::Literal["αβ",         nil],
                     "literal",   Net::IMAP::Literal["αβγδε",      nil],
                     "literal+",  Net::IMAP::Literal["αβγδε",     true],
                     "literal8",  Net::IMAP::Literal8["\0",      false],
                     "literal8+", Net::IMAP::Literal8["\0" * 2,    nil],
                     "literal8",  Net::IMAP::Literal8["\0" * 6,    nil],
                     "literal8+", Net::IMAP::Literal8["\0" * 8,   true],
                     "done")
      assert_equal("literal"   " {1}\r\n\r "                 \
                   "literal"   " {4+}\r\nαβ "                \
                   "literal"   " {10}\r\nαβγδε "             \
                   "literal+"  " {10+}\r\nαβγδε "            \
                   "literal8"  " ~{1}\r\n\0 "                \
                   "literal8+" " ~{2+}\r\n\0\0 "             \
                   "literal8"  " ~{6}\r\n\0\0\0\0\0\0 "      \
                   "literal8+" " ~{8+}\r\n\0\0\0\0\0\0\0\0 " \
                   "done".b,
                   server.commands.pop.args)
    end
  end

  test("send non-synchronizing literals with LITERAL+") do
    with_fake_server(
      with_extensions: %w[LITERAL+], greeting_capabilities: true,
    ) do |server, imap|
      def imap.send_test_args(*args) = send_command("TEST", *args)
      server.on "TEST", &:done_ok

      imap.config.max_non_synchronizing_literal = 5_000
      large = "\xff".b * 5_000
      imap.send_test_args Net::IMAP::Literal[large, nil]
      assert_equal("{5000+}\r\n#{large}".b, server.commands.pop.args)

      large = "\xff".b * 10_000
      imap.send_test_args Net::IMAP::Literal[large, nil]
      assert_equal("{10000}\r\n#{large}".b, server.commands.pop.args)

      imap.send_test_args Net::IMAP::Literal[large, true]
      assert_equal("{10000+}\r\n#{large}".b, server.commands.pop.args)
    end
  end

  test("send non-synchronizing literal that's too large for LITERAL-") do
    with_fake_server(
      with_extensions: %w[LITERAL-], greeting_capabilities: true,
      ignore_abrupt_eof: true, ignore_io_error: true
    ) do |server, imap|
      def imap.send_test_args(*args) = send_command("TEST", *args)
      server.on "TEST", &:done_ok
      assert_raise(Net::IMAP::DataFormatError) do
        imap.send_test_args Net::IMAP::Literal["\xff".b * 5000, true]
      end
      assert imap.disconnected?
    end
  end

  test("send non-synchronizing literal without known server support") do
    with_fake_server(
      with_extensions: %w[LITERAL+], greeting_capabilities: false,
      ignore_abrupt_eof: true, ignore_io_error: true
    ) do |server, imap|
      def imap.send_test_args(*args) = send_command("TEST", *args)
      server.on "TEST", &:done_ok
      assert_raise(Net::IMAP::DataFormatError) do
        imap.send_test_args Net::IMAP::Literal["\xff".b * 100, true]
      end
      assert imap.disconnected?
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
        rescue OpenSSL::SSL::SSLError
        end
      end
      sleep 0.001 until started
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

  def create_tcp_server
    return TCPServer.new(server_addr, 0)
  end

  def server_addr
    Addrinfo.tcp("localhost", 0).ip_address
  end

end
