# frozen_string_literal: true

require_relative "../../lib/helper"

class IMAPIdTest < Net::IMAP::TestCase
  # TODO: convert to use Net::IMAP::FakeServer::TestHelper
  include Net::IMAP::TestCase::SimpleTCPServerHelper

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

end
