# FHIR Sandbox R4

A self-contained, R4-compliant FHIR endpoint for demonstration and learning purposes.

## Quick Start

### Prerequisites
- Docker Desktop ≥ 4.38.0
- OpenJDK 21.0.7+
- Git

### Setup (< 90 seconds)

1. **Clone and navigate:**
   ```bash
   git clone <repository-url>
   cd fhir-sandbox-r4
   ```

2. **Start FHIR server:**
   ```bash
   docker-compose up -d
   ```

3. **Verify installation:**
   ```bash
   curl http://localhost:8080/fhir/metadata
   ```

### Basic Usage

**Create a Patient:**
```bash
curl -X POST http://localhost:8080/fhir/Patient \
  -H "Content-Type: application/fhir+json" \
  -d '{
    "resourceType": "Patient",
    "name": [{"family": "Doe", "given": ["John"]}],
    "gender": "male"
  }'
```

**Retrieve Patient:**
```bash
curl http://localhost:8080/fhir/Patient/1
```

## Development

### Running Tests
```bash
./tests/test_patient.sh
./tests/test_observation.sh
```

### Postman Collection
Import `postman/fhir-sandbox-collection.json` for interactive testing.

## Architecture

- **HAPI FHIR JPA Server** v8.2.0-2-tomcat
- **Database:** H2 in-memory (development)
- **FHIR Version:** R4
- **Platform:** Multi-arch (arm64/amd64)

## Security Note

⚠️ **Development Only**: This configuration uses H2 in-memory database and has CORS enabled for all origins. See `THREATS.md` for production hardening steps.

## Links

- [FHIR R4 Specification](http://hl7.org/fhir/R4/)
- [HAPI FHIR Documentation](https://hapifhir.io/)
- [Capability Statement](http://localhost:8080/fhir/metadata)

---

**Status:** Development Ready ✅