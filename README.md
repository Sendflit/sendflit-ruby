# sendflit — Ruby

Transactional email for applications and AI agents. Zero dependencies (stdlib only).

## Install

```bash
gem install sendflit
```

## Usage

```ruby
require "sendflit"

sf = SendFlit.new(api_key: "re_...")

res = sf.send(
  from: "you@yourdomain.com",
  to: "user@example.com",
  subject: "Confirm your email",
  html: "<p>Click <a href='...'>here</a>.</p>"
)
puts res["id"], res["status"]
```

### Attachments / batch

```ruby
sf.send(from: "billing@yourdomain.com", to: "u@example.com", subject: "Receipt",
        attachments: [{filename: "receipt.pdf", content: pdf_bytes}])

sf.batch([{from: "you@yourdomain.com", to: "a@example.com", subject: "Hi", html: "<p>A</p>"}])
```

### Webhook verification

```ruby
SendFlit.verify_webhook_signature(SECRET, raw_body, env["HTTP_X_SENDFLIT_SIGNATURE"])
```

Retries 429/5xx with backoff; errors raise `SendFlit::Error` with `.status`/`.body`.

MIT © SendFlit
