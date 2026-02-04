# Security Research

**Domain:** Rails Performance Gem Security
**Researched:** 2025-02-04
**Confidence:** MEDIUM

## Recommended Stack

### Core Security Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Rails Credentials | Rails 5.1+ | Encrypted secrets storage | Industry standard for Rails apps, encrypts secrets at rest, supports environment-specific credentials |
| `Rails.env.production?` checks | All Rails versions | Environment detection | Built-in Rails pattern, no additional dependencies, explicit production safety |
| SecureRandom | Ruby stdlib | Generate random credentials | Cryptographically secure, built-in, no external dependencies |
| ActiveSupport::SecurePassword | Rails 5.0+ | Password hashing | bcrypt-based hashing, Rails standard since Rails 8, automatic salting |

### Supporting Security Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `config.filter_parameters` | Built-in Rails | Redact sensitive data from logs | Always use for passwords, tokens, API keys |
| `config.require_master_key` | Built-in Rails | Prevent boot without credentials | Production deployments to enforce secrets availability |
| `config.action_dispatch.show_exceptions` | Built-in Rails | Control exception handling | Set to `:rescuable` or `:none` in production to prevent info leaks |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Brakeman | Static security analysis | Run in CI/CD, check for common vulnerabilities |
| Bundler-audit | Dependency vulnerability scanner | Check for CVEs in dependencies, run regularly |

## Installation

```bash
# Security tools (development/test group only)
group :development, :test do
  gem 'brakeman', require: false
  gem 'bundler-audit', require: false
end
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Rails Credentials | ENV variables | Use ENV for deployment-specific values (e.g., DATABASE_URL), use Credentials for app secrets |
| SecureRandom | UUID libraries | Use SecureRandom for tokens/passwords, UUID only for identifiers |
| `Rails.env.production?` | Custom env detection | Always use built-in Rails.env checks, never custom logic |
| bcrypt (via has_secure_password) | Other hashing algorithms | Only use bcrypt for passwords, never MD5/SHA1/unsalted hashes |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Hardcoded default passwords | CVE-level security risk, all installations have same credentials | Require user to set credentials via ENV or Credentials, raise error if not set |
| Debug mode in production | Leaks sensitive data (parameters, queries, stack traces), aids attackers | Disable debug in production, use proper logging levels |
| `Rails.logger.debug` for sensitive data | Logs may be accessible to attackers | Use Rails parameter filtering, never log credentials/tokens |
| Default credentials in source code | Visible in version control, can be leaked | Use encrypted credentials or ENV variables |
| `verify_access_proc = proc { true }` | Default allows all access | Default to proc that checks environment or raises error |

## Stack Patterns by Variant

**If production environment:**
- Raise error if credentials not explicitly set
- Disable all debug/logging features
- Validate all required secrets present on boot
- Use `config.require_master_key = true`
- Because: Production safety requires explicit configuration, fail-fast is better than silent insecurity

**If development/test environment:**
- Allow default credentials for convenience
- Enable debug mode with warnings
- Provide helpful setup instructions
- Because: Developer experience matters, security defaults can be relaxed in non-production

**If gem/library mode:**
- Never have default credentials
- Require explicit configuration via initializer
- Validate configuration on boot
- Raise descriptive errors for missing settings
- Because: Libraries should be secure by default, user must opt-in to functionality

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| Rails Credentials | Rails 5.1+, 6.x, 7.x, 8.0+ | Fully supported, encryption evolved from Rails 5.1 to 8.0 |
| `Rails.env.production?` | All Rails versions | Core API, stable across all versions |
| `config.filter_parameters` | Rails 3.0+, 4.x, 5.x, 6.x, 7.x, 8.0+ | Default filters changed in Rails 7.1 (precompile added) |
| ActiveSupport::SecurePassword | Rails 3.0+, 4.x, 5.x, 6.x, 7.x, 8.0+ | Standard authentication method, enhanced in Rails 8.0 |

## Sources

### Official Documentation (HIGH confidence)
- [Ruby on Rails Security Guide](https://guides.rubyonrails.org/security.html) — Covers credential management, logging, parameter filtering, Rails 8.0 authentication generator
- [Configuring Rails Applications](https://guides.rubyonrails.org/configuring.html) — Environment-specific configuration, credential storage, `config.filter_parameters`
- [GitLab Secure Coding Guidelines for Ruby](https://docs.gitlab.com/development/secure_coding_guidelines/ruby/) — Official GitLab security practices for Ruby/Rails

### Security Best Practices 2025 (MEDIUM confidence)
- [Ruby on Rails Security Audit Checklist 2025](https://www.reddit.com/r/rails/comments/1guvpgo/ruby_on_rails_security_audit_checklist_2025_23_proven/) — 2025 community-curated security practices
- [Essential Security Best Practices for Ruby on Rails](https://dev.to/harsh_u115/essential-security-best-practices-for-ruby-on-rails-4d68) — February 2025, covers secrets management
- [8 Essential Rails Security Gems (2025 Edition)](https://blog.devops.dev/8-essential-rails-security-gems-you-shouldnt-deploy-without-2025-edition-8b89f7e3c743) — Updated for 2025
- [A Complete Guide to Ruby on Rails Security Measures](https://railsdrop.com/2025/05/11/a-complete-guide-to-ruby-on-rails-security-measures/) — May 2025, comprehensive security coverage

### Logging and Debug Security (MEDIUM confidence)
- [Rails Debug Mode Security Risks](https://beaglesecurity.com/blog/rails-debug-mode-security-risks/) — June 4, 2025, debug mode exploitation
- [Ruby Supply Chain Security](https://www.mend.io/blog/how-to-mitigate-ruby-supply-chain-security-risks/) — Zero Trust philosophy for gems

### Authentication Patterns (MEDIUM confidence)
- [Rails 8 Authentication: Devise vs Clearance vs Built-In Options](https://blog.nonstopio.com/rails-8-authentication-devise-vs-clearance-vs-built-in-options-2169e91e8bcc) — December 30, 2024, Rails 8 native auth vs gems
- [Devise Gem Secure Defaults Discussion](https://www.reddit.com/r/rails/comments/1fr7zxv/do_you_still_plan_on_using_devise_with_rails_8/) — Community discussion on Rails 8 vs Devise
- [Devise GitHub Repository](https://github.com/heartcombo/devise) — Official gem, 240.8M downloads, reference for authentication patterns

### CVE References (LOW confidence - needs verification)
- [CVE-2025-27221: Ruby URI Gem Credential Leak](https://sentinelone.com/labs/research-vulnerabilities/) — 2025 Ruby gem credential vulnerability example

---
*Security research for: Rails Performance Gem*
*Researched: 2025-02-04*
