# Contributing to Azmi Bot

Thank you for your interest in contributing to Azmi Bot! This document provides guidelines and instructions for contributing.

## 🌟 Ways to Contribute

- **Bug Reports**: Open an issue describing the bug with reproduction steps
- **Feature Requests**: Propose new features or improvements via issues
- **Documentation**: Improve README, add examples, fix typos
- **Code**: Submit pull requests with bug fixes or new features
- **Testing**: Test the workflows and report issues
- **Share**: Share your experience and use cases with the community

## 🚀 Getting Started

### Prerequisites

Before contributing, make sure you have:

1. A GitHub account
2. Git installed locally
3. Familiarity with GitHub Actions
4. Access to Jira Cloud (for testing integrations)
5. OpenAI and Anthropic API keys (for testing)

### Setting Up Development Environment

1. **Fork the repository**
   ```bash
   # Click "Fork" button on GitHub
   ```

2. **Clone your fork**
   ```bash
   git clone https://github.com/YOUR_USERNAME/router.git
   cd router
   ```

3. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

4. **Make your changes**
   - Follow the existing code style
   - Update documentation if needed
   - Test your changes thoroughly

5. **Commit your changes**
   ```bash
   git add .
   git commit -m "feat: add your feature description"
   ```

   Use conventional commit messages:
   - `feat:` for new features
   - `fix:` for bug fixes
   - `docs:` for documentation changes
   - `chore:` for maintenance tasks
   - `refactor:` for code refactoring

6. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```

7. **Open a Pull Request**
   - Go to the original repository
   - Click "New Pull Request"
   - Select your fork and branch
   - Fill in the PR template

## 📝 Pull Request Guidelines

### Before Submitting

- [ ] Test your changes in a real environment
- [ ] Update README.md if you changed functionality
- [ ] Add comments to complex code sections
- [ ] Ensure workflow YAML files are valid
- [ ] Check that scripts have proper error handling

### PR Description Should Include

1. **What**: What does this PR do?
2. **Why**: Why is this change needed?
3. **How**: How does it work?
4. **Testing**: How did you test it?
5. **Screenshots**: If applicable, add before/after screenshots

### Example PR Template

```markdown
## Description
Adds support for multi-image attachments in revision requests.

## Motivation
Users often need to attach multiple screenshots to show before/after comparisons.

## Changes
- Modified `fetch-jira-attachments.sh` to handle multiple images
- Updated `revision-router.yml` to pass multiple images in payload
- Added image count limit (max 3 images)

## Testing
- Tested with 1, 2, and 3 images attached to Jira comment
- Verified image optimization reduces size by 90%+
- Confirmed dispatch payload stays under GitHub limit

## Screenshots
![image-optimization-logs](...)
```

## 🧪 Testing

### Testing Router Workflow

1. Create a test Jira instance or use a sandbox
2. Set up GitHub secrets in your fork
3. Create a test ticket and assign to bot
4. Monitor workflow runs in Actions tab

### Testing Target Repo Workflows

1. Set up a sample repository with the workflows
2. Manually trigger `repository_dispatch` events
3. Verify PRs are created correctly
4. Check Codex review and auto-merge behavior

### Manual Dispatch Testing

```bash
# Test router workflow
curl -X POST \
  -H "Authorization: Bearer YOUR_PAT" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/YOUR_USERNAME/router/dispatches \
  -d '{"event_type":"ai-coding-request","client_payload":{"issue_key":"TEST-1","title":"Test Task","description":"Test description","target_repo":"YOUR_ORG/YOUR_REPO"}}'
```

## 🐛 Reporting Bugs

### Before Reporting

1. Check if the issue already exists in [Issues](https://github.com/htuzel/router/issues)
2. Verify you're using the latest version
3. Test with minimal configuration to isolate the issue

### Bug Report Should Include

- **Environment**: OS, GitHub Actions runner version
- **Configuration**: Relevant workflow YAML snippets
- **Expected behavior**: What should happen
- **Actual behavior**: What actually happens
- **Steps to reproduce**: Detailed steps
- **Logs**: Workflow run logs (sanitize sensitive data!)
- **Screenshots**: If applicable

## 💡 Feature Requests

We welcome feature requests! When proposing a feature:

1. **Search existing issues** to avoid duplicates
2. **Describe the use case** - what problem does it solve?
3. **Propose a solution** - how would you implement it?
4. **Consider alternatives** - what other approaches exist?
5. **Add examples** - provide code snippets or mockups

## 🎨 Code Style Guidelines

### YAML Workflows

- Use 2 spaces for indentation
- Add comments for complex logic
- Keep secrets in GitHub Secrets, never hardcode
- Use descriptive step names
- Group related environment variables

### Bash Scripts

- Use `set -euo pipefail` for safety
- Add comments for non-obvious logic
- Handle errors gracefully
- Use meaningful variable names in UPPERCASE
- Quote variables to prevent word splitting

### Documentation

- Use clear, concise language
- Add code examples for complex features
- Keep README.md table of contents updated
- Use emoji sparingly and consistently
- Ensure markdown renders correctly on GitHub

## 🔒 Security

### Reporting Security Vulnerabilities

**Do NOT open a public issue for security vulnerabilities.**

Instead:
1. Email security concerns to the maintainers (see SECURITY.md)
2. Include detailed steps to reproduce
3. Allow time for a fix before public disclosure

### Security Best Practices

- Never commit API keys or secrets
- Sanitize logs before sharing
- Use least-privilege access for tokens
- Validate all external inputs
- Use secure communication (HTTPS)

## 📄 License

By contributing, you agree that your contributions will be licensed under the MIT License.

## 🤝 Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## ❓ Questions?

- **General questions**: Open a [Discussion](https://github.com/htuzel/router/discussions)
- **Bugs**: Open an [Issue](https://github.com/htuzel/router/issues)
- **Feature requests**: Open an [Issue](https://github.com/htuzel/router/issues) with "Feature Request" label

## 🙏 Thank You!

Every contribution, no matter how small, is valuable and appreciated. Thank you for helping make Azmi Bot better!

---

**Happy Contributing!** 🎉
