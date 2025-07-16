#!/bin/bash

# FHIR Patient Operations Test Suite
# Tests CREATE and READ operations for Patient resources

set -e  # Exit on any error

# Configuration
FHIR_BASE_URL="http://localhost:8080/fhir"
TEST_PATIENT_JSON="tests/test-patient.json"
TEST_RESULTS_DIR="tests/results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$TEST_RESULTS_DIR/patient_test_$TIMESTAMP.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=0

# Helper functions
log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

test_start() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    log "${YELLOW}[TEST $TOTAL_TESTS]${NC} $1"
}

test_pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    log "${GREEN}✅ PASS${NC}: $1"
}

test_fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    log "${RED}❌ FAIL${NC}: $1"
    if [[ "$2" != "continue" ]]; then
        exit 1
    fi
}

# Setup test environment
setup_tests() {
    log "${YELLOW}Setting up Patient tests...${NC}"
    mkdir -p "$TEST_RESULTS_DIR"
    
    # Create test patient JSON
    cat > "$TEST_PATIENT_JSON" << 'EOF'
{
  "resourceType": "Patient",
  "name": [
    {
      "family": "TestPatient",
      "given": ["Integration", "Test"]
    }
  ],
  "gender": "unknown",
  "birthDate": "2000-01-01",
  "identifier": [
    {
      "use": "usual",
      "type": {
        "coding": [
          {
            "system": "http://terminology.hl7.org/CodeSystem/v2-0203",
            "code": "MR",
            "display": "Medical Record Number"
          }
        ]
      },
      "system": "http://hospital.test.org",
      "value": "TEST-MRN-001"
    }
  ],
  "active": true
}
EOF
    
    # Test server connectivity
    if ! curl -s -f "$FHIR_BASE_URL/metadata" > /dev/null; then
        test_fail "FHIR server not available at $FHIR_BASE_URL"
    fi
    
    log "${GREEN}✅ Setup complete${NC}"
}

# Test 1: Create Patient (POST)
test_create_patient() {
    test_start "Create Patient via POST"
    
    # Make POST request and capture response
    RESPONSE=$(curl -s -X POST "$FHIR_BASE_URL/Patient" \
        -H "Content-Type: application/fhir+json" \
        -H "Accept: application/fhir+json" \
        -d @"$TEST_PATIENT_JSON" \
        -w "HTTPSTATUS:%{http_code};LOCATION:%{header_location}")
    
    HTTP_CODE=$(echo "$RESPONSE" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
    LOCATION=$(echo "$RESPONSE" | grep -o "LOCATION:[^;]*" | cut -d: -f2-)
    BODY=$(echo "$RESPONSE" | sed 's/HTTPSTATUS:[0-9]*;//g' | sed 's/LOCATION:[^;]*;//g')
    
    # Test HTTP status code
    if [[ "$HTTP_CODE" == "201" ]]; then
        test_pass "HTTP 201 Created response"
    else
        test_fail "Expected HTTP 201, got $HTTP_CODE"
        echo "$BODY" >> "$LOG_FILE"
        return 1
    fi
    
    # Test Location header
    if [[ -n "$LOCATION" ]]; then
        test_pass "Location header present: $LOCATION"
        # Extract patient ID from location
        PATIENT_ID=$(echo "$LOCATION" | sed -n 's/.*Patient\/\([0-9]*\).*/\1/p')
        echo "$PATIENT_ID" > "$TEST_RESULTS_DIR/patient_id.txt"
    else
        test_fail "Location header missing"
        return 1
    fi
    
    # Test response contains Patient resource
    if echo "$BODY" | jq -e '.resourceType == "Patient"' > /dev/null; then
        test_pass "Response contains Patient resource"
    else
        test_fail "Response does not contain Patient resource"
        echo "$BODY" >> "$LOG_FILE"
        return 1
    fi
    
    # Test patient has correct name
    FAMILY_NAME=$(echo "$BODY" | jq -r '.name[0].family')
    if [[ "$FAMILY_NAME" == "TestPatient" ]]; then
        test_pass "Patient name correctly set"
    else
        test_fail "Patient name incorrect. Expected 'TestPatient', got '$FAMILY_NAME'"
    fi
    
    # Test resource has ID
    RESOURCE_ID=$(echo "$BODY" | jq -r '.id')
    if [[ "$RESOURCE_ID" != "null" && -n "$RESOURCE_ID" ]]; then
        test_pass "Patient resource has ID: $RESOURCE_ID"
    else
        test_fail "Patient resource missing ID"
    fi
    
    # Test resource has metadata
    if echo "$BODY" | jq -e '.meta.versionId' > /dev/null; then
        test_pass "Patient has version metadata"
    else
        test_fail "Patient missing version metadata"
    fi
    
    # Save response for next test
    echo "$BODY" > "$TEST_RESULTS_DIR/created_patient.json"
}

# Test 2: Read Patient (GET)
test_read_patient() {
    test_start "Read Patient via GET"
    
    # Get patient ID from previous test
    if [[ ! -f "$TEST_RESULTS_DIR/patient_id.txt" ]]; then
        test_fail "Patient ID not available from CREATE test"
        return 1
    fi
    
    PATIENT_ID=$(cat "$TEST_RESULTS_DIR/patient_id.txt")
    
    # Make GET request
    RESPONSE=$(curl -s "$FHIR_BASE_URL/Patient/$PATIENT_ID" \
        -H "Accept: application/fhir+json" \
        -w "HTTPSTATUS:%{http_code}")
    
    HTTP_CODE=$(echo "$RESPONSE" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
    BODY=$(echo "$RESPONSE" | sed 's/HTTPSTATUS:[0-9]*//g')
    
    # Test HTTP status code
    if [[ "$HTTP_CODE" == "200" ]]; then
        test_pass "HTTP 200 OK response"
    else
        test_fail "Expected HTTP 200, got $HTTP_CODE"
        echo "$BODY" >> "$LOG_FILE"
        return 1
    fi
    
    # Test response is Patient resource
    if echo "$BODY" | jq -e '.resourceType == "Patient"' > /dev/null; then
        test_pass "Response is Patient resource"
    else
        test_fail "Response is not Patient resource"
        return 1
    fi
    
    # Test patient ID matches
    RETRIEVED_ID=$(echo "$BODY" | jq -r '.id')
    if [[ "$RETRIEVED_ID" == "$PATIENT_ID" ]]; then
        test_pass "Patient ID matches: $PATIENT_ID"
    else
        test_fail "Patient ID mismatch. Expected $PATIENT_ID, got $RETRIEVED_ID"
    fi
    
    # Test patient data integrity
    FAMILY_NAME=$(echo "$BODY" | jq -r '.name[0].family')
    if [[ "$FAMILY_NAME" == "TestPatient" ]]; then
        test_pass "Patient data integrity verified"
    else
        test_fail "Patient data corruption detected"
    fi
    
    # Test metadata consistency
    if echo "$BODY" | jq -e '.meta.versionId == "1"' > /dev/null; then
        test_pass "Version metadata consistent"
    else
        test_fail "Version metadata inconsistent"
    fi
}

# Test 3: Read Non-existent Patient (GET)
test_read_nonexistent_patient() {
    test_start "Read Non-existent Patient"
    
    # Try to read patient with ID 99999
    RESPONSE=$(curl -s "$FHIR_BASE_URL/Patient/99999" \
        -H "Accept: application/fhir+json" \
        -w "HTTPSTATUS:%{http_code}")
    
    HTTP_CODE=$(echo "$RESPONSE" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
    
    # Test HTTP status code
    if [[ "$HTTP_CODE" == "404" ]]; then
        test_pass "HTTP 404 Not Found for non-existent patient"
    else
        test_fail "Expected HTTP 404, got $HTTP_CODE"
    fi
}

# Test 4: Create Invalid Patient
test_create_invalid_patient() {
    test_start "Create Invalid Patient"
    
    # Create invalid patient JSON (missing resourceType)
    INVALID_JSON='{"name": [{"family": "Invalid"}]}'
    
    RESPONSE=$(curl -s -X POST "$FHIR_BASE_URL/Patient" \
        -H "Content-Type: application/fhir+json" \
        -H "Accept: application/fhir+json" \
        -d "$INVALID_JSON" \
        -w "HTTPSTATUS:%{http_code}")
    
    HTTP_CODE=$(echo "$RESPONSE" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
    
    # Test HTTP status code (should be 4xx)
    if [[ "$HTTP_CODE" =~ ^4[0-9][0-9]$ ]]; then
        test_pass "HTTP 4xx error for invalid patient"
    else
        test_fail "Expected HTTP 4xx, got $HTTP_CODE"
    fi
}

# Cleanup
cleanup_tests() {
    log "${YELLOW}Cleaning up test environment...${NC}"
    rm -f "$TEST_PATIENT_JSON"
    log "${GREEN}✅ Cleanup complete${NC}"
}

# Main execution
main() {
    log "${YELLOW}======================================${NC}"
    log "${YELLOW}  FHIR Patient Operations Test Suite  ${NC}"
    log "${YELLOW}======================================${NC}"
    log "Start time: $(date)"
    log "FHIR Base URL: $FHIR_BASE_URL"
    log "Log file: $LOG_FILE"
    log ""
    
    # Setup
    setup_tests
    
    # Run tests
    test_create_patient
    test_read_patient
    test_read_nonexistent_patient
    test_create_invalid_patient
    
    # Cleanup
    cleanup_tests
    
    # Summary
    log ""
    log "${YELLOW}======================================${NC}"
    log "${YELLOW}           TEST SUMMARY               ${NC}"
    log "${YELLOW}======================================${NC}"
    log "Total tests: $TOTAL_TESTS"
    log "Passed: ${GREEN}$TESTS_PASSED${NC}"
    log "Failed: ${RED}$TESTS_FAILED${NC}"
    log "End time: $(date)"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log "${GREEN}🎉 ALL TESTS PASSED!${NC}"
        exit 0
    else
        log "${RED}💥 $TESTS_FAILED TEST(S) FAILED!${NC}"
        exit 1
    fi
}

# Run main function
main "$@"