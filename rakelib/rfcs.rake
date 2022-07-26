# frozen_string_literal: true

RFCS = {

  # Core IMAP RFCs
  2060 => "IMAP4rev1 (obsolete)",
  3501 => "IMAP4rev1", # supported by nearly all email servers
  4466 => "Collected Extensions to IMAP4 ABNF",
  9051 => "IMAP4rev2",

  # RFC-9051 Normative References (not a complete list)
  2152 => "UTF-7",
  2180 => "IMAP4 Multi-Accessed Mailbox Practice",
  2683 => "IMAP4 Implementation Recommendations",
  5258 => "IMAP4 LIST-EXTENDED Extensions",
  5788 => "IMAP4 keyword registry",
  8314 => "Cleartext Considered Obsolete: Use of TLS for Email",

  # SASL
  4422 => "SASL, AUTH=EXTERNAL",
  4959 => "IMAP SASL-IR",
  # stringprep
  3454 => "stringprep",
  4013 => "SASLprep",
  8265 => "PRECIS", # obsoletes SASLprep?
  # SASL mechanisms (not a complete list)
  2195 => "AUTH=CRAM-MD5",
  4505 => "AUTH=ANONYMOUS",
  4616 => "AUTH=PLAIN",
  4752 => "AUTH=GSSAPI (Kerberos V5)",
  5802 => "AUTH=SCRAM-SHA-1",
  6331 => "AUTH=DIGEST-MD5",
  6595 => "AUTH=SAML20",
  6616 => "AUTH=OPENID20",
  7628 => "AUTH=OAUTH10A AUTH=OAUTHBEARER",
  7677 => "AUTH=SCRAM-SHA-256",

  # "Informational" RFCs
  1733 => "Distributed E-Mail Models in IMAP4",
  4549 => "Synchronization Operations for Disconnected IMAP4 Clients",
  6151 => "Updated Security Considerations for MD5 Message-Digest and HMAC-MD5",

  # "Best Current Practice" RFCs
  7525 => "Recommendations for Secure Use of TLS and DTLS",

  # related email specifications
  6376 => "DomainKeys Identified Mail (DKIM) Signatures",
  6409 => "Message Submission for Mail",

  # Other IMAP4 "Standards Track" RFCs
  5092 => "IMAP URL Scheme",
  5530 => "IMAP Response Codes",
  6186 => "Use of SRV Records for Locating Email Submission/Access Services",
  8305 => "Happy Eyeballs Version 2: Better Connectivity Using Concurrency",

  # IMAP4 Extensions
  2087 => "IMAP QUOTA",
  2177 => "IMAP IDLE",
  2193 => "IMAP MAILBOX-REFERRALS",
  2342 => "IMAP NAMESPACE",
  3348 => "IMAP CHILDREN",
  3516 => "IMAP BINARY",
  3691 => "IMAP UNSELECT",
  4314 => "IMAP ACL, RIGHTS=",
  4315 => "IMAP UIDPLUS",
  4731 => "IMAP ESEARCH (for controlling what is returned)",
  5161 => "IMAP ENABLE Extension",
  5182 => "IMAP SEARCHRES (for referencing the last result)",
  5255 => "IMAP I18N: LANGUAGE, I18NLEVEL={1,2}",
  5256 => "IMAP SORT, THREAD",
  5465 => "IMAP NOTIFY",
  5819 => "IMAP LIST-STATUS",
  6154 => "IMAP SPECIAL-USE, CREATE-SPECIAL-USE",
  6851 => "IMAP MOVE",
  6855 => "IMAP UTF8=",
  7162 => "IMAP CONDSTORE and QRESYNC (quick resynchronization)",
  7888 => "IMAP LITERAL+, LITERAL- (Non-synchronizing Literals)",

  8437 => "IMAP UNAUTHENTICATE",
  8438 => "IMAP STATUS=SIZE",
  8474 => "IMAP OBJECTID",

}.freeze

task :rfcs => RFCS.keys.map {|n| "rfcs/rfc%04d.txt" % [n] }

RFC_RE = %r{rfcs/rfc(\d+).*\.txt}.freeze
rule RFC_RE do |t|
  require "fileutils"
  FileUtils.mkpath "rfcs"
  require "net/http"
  t.name =~ RFC_RE
  rfc_url = URI("https://www.rfc-editor.org/rfc/rfc#$1.txt")
  rfc_txt = Net::HTTP.get(rfc_url)
  File.write(t.name, rfc_txt)
end

CLEAN.include "rfcs/rfc*.txt"
