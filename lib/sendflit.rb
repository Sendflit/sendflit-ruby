# frozen_string_literal: true

require "net/http"
require "json"
require "openssl"
require "time"

# SendFlit Ruby SDK — zero dependencies (stdlib only).
# Transactional email API for applications and AI agents.
#
#   sf = SendFlit.new(api_key: "re_...")
#   sf.send(from: "you@yourdomain.com", to: "user@example.com",
#           subject: "Confirm", html: "<p>…</p>")
class SendFlit
  DEFAULT_BASE = "https://api.sendflit.com"
  VERSION = "1.0.0"

  class Error < StandardError
    attr_reader :status, :body

    def initialize(msg, status = 0, body = nil)
      super(msg)
      @status = status
      @body = body
    end
  end

  # @param api_key [String] required, starts with "re_"
  # @param base_url [String] API root
  # @param timeout [Integer] seconds
  # @param max_retries [Integer] retries for 429/5xx
  def initialize(api_key:, base_url: DEFAULT_BASE, timeout: 15, max_retries: 2)
    raise TypeError, "SendFlit: api_key is required" if api_key.to_s.empty?

    @api_key = api_key
    @base = base_url.sub(%r{/+\z}, "")
    @timeout = timeout
    @max_retries = max_retries
    @uri = URI.parse(@base)
  end

  # Send a transactional email.
  # attachments: [{filename:, content: (String), content_type:}] — content base64'd for you.
  def send(**email)
    payload = normalize(email)
    request(:post, "/v1/email", payload)
  end

  # Send up to 100 emails in one call.
  def batch(emails)
    raise TypeError, "batch expects a non-empty array" if emails.nil? || emails.empty?
    raise RangeError, "batch accepts at most 100 emails" if emails.length > 100

    request(:post, "/v1/emails/batch", {emails: emails.map { |e| normalize(e) }})
  end

  def list_emails(limit: nil, offset: nil, status: nil)
    q = {limit: limit, offset: offset, status: status}.compact
    request(:get, "/v1/emails#{q.empty? ? "" : "?" + URI.encode_www_form(q)}")
  end

  def get_email(id) = request(:get, "/v1/emails/#{id}")
  def cancel_email(id) = request(:delete, "/v1/emails/#{id}")

  def add_domain(name) = request(:post, "/v1/domains", {name: name})
  def list_domains = request(:get, "/v1/domains")
  def verify_domain(id) = request(:post, "/v1/domains/#{id}/verify", nil)

  def create_template(name:, subject:, html: "", text: "")
    request(:post, "/v1/templates", {name: name, subject: subject, html: html, text: text})
  end
  def list_templates = request(:get, "/v1/templates")

  def add_contact(email:, name: "", audience: "default", data: nil)
    payload = {email: email, name: name, audience: audience}
    payload[:data] = data if data
    request(:post, "/v1/contacts", payload)
  end

  def list_contacts(limit: nil, offset: nil, audience: nil)
    q = {limit: limit, offset: offset, audience: audience}.compact
    request(:get, "/v1/contacts#{q.empty? ? "" : "?" + URI.encode_www_form(q)}")
  end

  def suppress(email, reason: "unsubscribe")
    request(:post, "/v1/suppressions", {email: email, reason: reason})
  end

  def usage = request(:get, "/v1/usage")

  # Liveness probe (root-level, not /v1).
  def health
    r = Net::HTTP.get_response(build_uri("/health"))
    JSON.parse(r.body || "{}")
  end

  # Verify an X-Sendflit-Signature header against the raw body.
  def self.verify_webhook_signature(secret, raw_body, signature)
    expected = "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", secret, raw_body)
    OpenSSL.secure_compare(expected, signature.to_s)
  end

  private

  def normalize(e)
    out = {}
    e.each do |k, v|
      next if v.nil?

      key = {reply_to: :reply_to, cc: :cc, bcc: :bcc}[k] || k
      out[key] = v
    end
    out[:cc] = Array(out[:cc]) if out[:cc]
    out[:bcc] = Array(out[:bcc]) if out[:bcc]
    if out[:attachments]
      out[:attachments] = out[:attachments].map do |a|
        {
          filename: a[:filename],
          content_b64: [a[:content]].pack("m0"),
          content_type: a[:content_type] || "application/octet-stream"
        }
      end
    end
    out
  end

  def build_uri(path)
    URI.parse(@base + path)
  end

  def request(method, path, body)
    uri = build_uri(path)
    attempt = 0
    loop do
      req = (Net::HTTP::Post.new(uri) if method == :post) ||
            (method == :delete ? Net::HTTP::Delete.new(uri) : Net::HTTP::Get.new(uri))
      req["Authorization"] = "Bearer #{@api_key}"
      req["User-Agent"] = "sendflit-ruby/#{VERSION}"
      if body
        req["Content-Type"] = "application/json"
        req.body = JSON.generate(body)
      end
      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https",
                            open_timeout: @timeout, read_timeout: @timeout) do |http|
        http.request(req)
      end
      data = begin
        JSON.parse(res.body || "{}")
      rescue JSON::ParserError
        {"raw" => res.body}
      end
      return data if res.is_a?(Net::HTTPSuccess)

      retryable = res.code.to_i == 429 || res.code.to_i >= 500
      if retryable && attempt < @max_retries
        attempt += 1
        ra = res["retry-after"].to_i
        sleep(ra.positive? ? ra : 0.3 * (2**attempt))
        next
      end
      detail = data["detail"]
      msg = if detail.is_a?(String)
             detail
           elsif detail.is_a?(Array)
             detail.map { |d| d["msg"] }.join("; ")
           else
             "SendFlit API error (#{res.code})"
           end
      raise Error.new(msg, res.code.to_i, data)
    end
  end
end
