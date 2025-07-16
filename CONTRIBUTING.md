# Contributing to FHIR Sandbox R4

Thank you for your interest in contributing to the FHIR Sandbox R4 project! This document provides guidelines and information for contributors.

## 🎯 Project Overview

This project is a **self-contained FHIR R4 endpoint** designed for:
- **Learning:** Hands-on FHIR implementation experience
- **Development:** Modern DevOps practices showcase
- **Education:** Understanding healthcare data interoperability

## 🚀 Getting Started

### Prerequisites

Before contributing, ensure you have:
- **Docker Desktop** ≥ 4.38.0
- **OpenJDK 21.0.7+** (`brew install openjdk@21`)
- **Git** and **curl**
- **jq** for JSON processing (`brew install jq`)
- **Task** for build automation (`brew install go-task/tap/go-task`)

### Development Setup

1. **Fork the repository:**
   ```bash
   git clone https://github.com/your-username/fhir-sandbox-r4.git
   cd fhir-sandbox-r4
   ```

2. **Start the development environment:**
   ```bash
   task start
   ```

3. **Verify setup:**
   ```bash
   task status
   task test
   ```

## 📋 Development Workflow

### Branch Strategy

- **main:** Production-ready code
- **develop:** Integration branch for features
- **feature/*:** New features and enhancements
- **bugfix/*:** Bug fixes
- **hotfix/*:** Critical production fixes

### Standard Workflow

1. **Create feature branch:**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make changes and test:**
   ```bash
   # Make your changes
   task test
   ```

3. **Commit with clear messages:**
   ```bash
   git commit -m "Add: Brief description of change"
   ```

4. **Push and create Pull Request:**
   ```bash
   git push origin feature/your-feature-name
   ```

## 🧪 Testing Requirements

### Before Submitting

All contributions must pass:
- **Unit Tests:** `./tests/test_patient.sh`
- **Integration Tests:** `./tests/test_observation.sh`
- **End-to-End Tests:** `./tests/test_integration.sh`

### Running Tests

```bash
# Run all tests
task test

# Run specific test suites
task test-patient
task test-observation
task test-integration

# Simulate CI/CD pipeline
task test-ci
```

### Test Coverage Requirements

- **New Features:** Must include corresponding tests
- **Bug Fixes:** Must include regression tests
- **Performance:** Must not degrade existing benchmarks
- **Security:** Must not introduce vulnerabilities

## 📝 Code Standards

### Shell Scripts

- Use `#!/bin/bash` shebang
- Include error handling with `set -e`
- Use meaningful variable names
- Add comments for complex logic
- Follow consistent formatting

**Example:**
```bash
#!/bin/bash
set -e

# Configuration
FHIR_BASE_URL="http://localhost:8080/fhir"
TEST_NAME="Patient Operations"

# Test function
test_patient_create() {
    local patient_json="$1"
    # Implementation...
}
```

### Docker Configuration

- Use specific version tags (not `latest`)
- Include health checks
- Set appropriate resource limits
- Document environment variables

### Documentation

- Update README.md for new features
- Include inline comments for complex code
- Provide usage examples
- Update API documentation

## 🔒 Security Guidelines

### Development Security

- **Never commit secrets** (API keys, passwords)
- **Validate all inputs** in test scripts
- **Use secure defaults** in configurations
- **Document security considerations**

### Production Considerations

- Review `THREATS.md` for security implications
- Consider impact on production hardening
- Validate against OWASP guidelines
- Test with security scanners

## 🚀 CI/CD Integration

### GitHub Actions

The project uses GitHub Actions for CI/CD:
- **Automated Testing:** All PRs trigger test suite
- **Multi-Platform:** Tests run on ARM64 and AMD64
- **Security Scanning:** Trivy vulnerability analysis
- **Performance Testing:** Apache Bench load testing

### Local CI Simulation

Before submitting, run:
```bash
task test-ci
```

This simulates the full CI/CD pipeline locally.

## 📊 Performance Guidelines

### Benchmarks

Maintain or improve these performance targets:
- **Patient CREATE:** <500ms
- **Patient READ:** <200ms
- **Observation CREATE:** <500ms
- **Observation SEARCH:** <1000ms
- **Concurrent Operations:** 5 simultaneous requests
- **Load Test:** 20 operations in <1 second

### Optimization Tips

- Use efficient API calls
- Minimize Docker layer size
- Optimize test execution time
- Cache when appropriate

## 🐛 Bug Reports

### Issue Template

When reporting bugs, include:
- **Environment:** OS, Docker version, etc.
- **Steps to reproduce:** Clear, minimal example
- **Expected behavior:** What should happen
- **Actual behavior:** What actually happens
- **Logs:** Relevant error messages

### Bug Fix Process

1. **Reproduce the bug** locally
2. **Write failing test** that demonstrates the issue
3. **Fix the bug** while maintaining existing functionality
4. **Verify fix** with tests
5. **Submit PR** with clear description

## ✨ Feature Requests

### Before Submitting

Consider:
- **Alignment:** Does it fit project goals?
- **Scope:** Is it appropriately sized?
- **Impact:** What's the benefit/cost ratio?
- **Compatibility:** Does it break existing functionality?

### Feature Development

1. **Discuss in Issue** before implementation
2. **Design approach** with maintainers
3. **Implement incrementally** with tests
4. **Document thoroughly** with examples
5. **Update dependencies** if needed

## 📚 Common Contribution Areas

### High-Impact Areas

- **Test Coverage:** Additional test scenarios
- **Documentation:** Tutorials, examples, guides
- **Performance:** Optimization and benchmarking
- **Security:** Hardening and vulnerability fixes
- **FHIR Compliance:** R4 specification adherence

### Good First Issues

- **Documentation updates**
- **Test case additions**
- **Configuration improvements**
- **Error message enhancements**

## 🔄 Pull Request Process

### PR Checklist

- [ ] Tests pass locally (`task test`)
- [ ] Documentation updated
- [ ] Commit messages are clear
- [ ] Branch is up to date with main
- [ ] No merge conflicts
- [ ] Security considerations addressed

### Review Process

1. **Automated Checks:** GitHub Actions must pass
2. **Code Review:** Maintainer review required
3. **Testing:** Manual testing if needed
4. **Integration:** Merge after approval

### PR Template

```markdown
## Summary
Brief description of changes

## Changes Made
- Change 1
- Change 2

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed

## Documentation
- [ ] README updated
- [ ] API docs updated
- [ ] Examples provided

## Security
- [ ] No secrets committed
- [ ] Security implications considered
- [ ] Vulnerability scanning passed
```

## 🏷️ Release Process

### Versioning

We use [Semantic Versioning](https://semver.org/):
- **MAJOR:** Breaking changes
- **MINOR:** New features (backward compatible)
- **PATCH:** Bug fixes (backward compatible)

### Release Checklist

- [ ] All tests passing
- [ ] Documentation updated
- [ ] Security scan clean
- [ ] Performance benchmarks met
- [ ] Deployment artifacts created

## 🤝 Community Guidelines

### Code of Conduct

- **Be respectful** and inclusive
- **Provide constructive feedback**
- **Help others learn**
- **Follow project guidelines**

### Communication

- **Issues:** For bugs and feature requests
- **Pull Requests:** For code contributions
- **Discussions:** For questions and ideas

## 📞 Getting Help

### Resources

- **Project Documentation:** README.md
- **FHIR Specification:** [hl7.org/fhir](http://hl7.org/fhir/R4/)
- **HAPI FHIR Docs:** [hapifhir.io](https://hapifhir.io/)
- **Docker Documentation:** [docs.docker.com](https://docs.docker.com/)

### Contact

- **Issues:** GitHub Issues for bugs/features
- **Security:** Create security advisory for vulnerabilities
- **General:** Discussion threads for questions

## 📄 License

By contributing, you agree that your contributions will be licensed under the Apache License 2.0.

---

**Thank you for contributing to FHIR Sandbox R4!** 🎉

Your contributions help make this project a better resource for FHIR learning and demonstration.