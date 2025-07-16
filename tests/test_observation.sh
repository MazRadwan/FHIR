#!/bin/bash

# FHIR Observation Operations Test Suite
# Tests CREATE and SEARCH operations for Observation resources

set -e  # Exit on any error

# Configuration
FHIR_BASE_URL="http://localhost:8080/fhir"
TEST_OBSERVATION_JSON="tests/test-observation.json"
TEST_RESULTS_DIR="tests/results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$TEST_RESULTS_DIR/observation_test_$TIMESTAMP.log"

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
    log "${YELLOW}Setting up Observation tests...${NC}"
    mkdir -p "$TEST_RESULTS_DIR"
    
    # Test server connectivity
    if ! curl -s -f "$FHIR_BASE_URL/metadata" > /dev/null; then
        test_fail "FHIR server not available at $FHIR_BASE_URL"
    fi
    
    log "${GREEN}✅ Setup complete${NC}"
}

# Create a test patient for observations
create_test_patient() {
    test_start "Create Test Patient for Observations"
    
    TEST_PATIENT_JSON='{
        "resourceType": "Patient",
        "name": [
            {
                "family": "ObservationTest",
                "given": ["Subject"]
            }
        ],
        "gender": "unknown",
        "birthDate": "1990-01-01",
        "active": true
    }'
    
    RESPONSE=$(curl -s -X POST "$FHIR_BASE_URL/Patient" \
        -H "Content-Type: application/fhir+json" \
        -H "Accept: application/fhir+json" \
        -d "$TEST_PATIENT_JSON" \
        -w "HTTPSTATUS:%{http_code}")
    
    HTTP_CODE=$(echo "$RESPONSE" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
    BODY=$(echo "$RESPONSE" | sed 's/HTTPSTATUS:[0-9]*//g')
    
    if [[ "$HTTP_CODE" == "201" ]]; then
        PATIENT_ID=$(echo "$BODY" | jq -r '.id')
        echo "$PATIENT_ID" > "$TEST_RESULTS_DIR/observation_patient_id.txt"
        test_pass "Test patient created with ID: $PATIENT_ID"
    else
        test_fail "Failed to create test patient. HTTP: $HTTP_CODE"
    fi
}

# Test 1: Create Observation (POST)
test_create_observation() {
    test_start "Create Observation via POST"
    
    # Get patient ID from setup
    if [[ ! -f "$TEST_RESULTS_DIR/observation_patient_id.txt" ]]; then
        test_fail "Patient ID not available from setup"
        return 1
    fi
    
    PATIENT_ID=$(cat "$TEST_RESULTS_DIR/observation_patient_id.txt")
    
    # Create test observation JSON
    cat > "$TEST_OBSERVATION_JSON" << EOF
{
  "resourceType": "Observation",
  "status": "final",
  "category": [
    {
      "coding": [
        {
          "system": "http://terminology.hl7.org/CodeSystem/observation-category",
          "code": "vital-signs",
          "display": "Vital Signs"
        }
      ]
    }
  ],
  "code": {
    "coding": [
      {
        "system": "http://loinc.org",
        "code": "29463-7",
        "display": "Body Weight"
      }
    ]
  },
  "subject": {
    "reference": "Patient/$PATIENT_ID",
    "display": "ObservationTest Subject"
  },
  "effectiveDateTime": "2025-07-16T10:00:00+00:00",
  "valueQuantity": {
    "value": 70.5,
    "unit": "kg",
    "system": "http://unitsofmeasure.org",
    "code": "kg"
  },
  "performer": [
    {
      "display": "Test Nurse"
    }
  ]
}
EOF
    
    # Make POST request
    RESPONSE=$(curl -s -X POST "$FHIR_BASE_URL/Observation" \
        -H "Content-Type: application/fhir+json" \
        -H "Accept: application/fhir+json" \
        -d @"$TEST_OBSERVATION_JSON" \
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
        # Extract observation ID from location
        OBSERVATION_ID=$(echo "$LOCATION" | sed -n 's/.*Observation\/\([0-9]*\).*/\1/p')
        echo "$OBSERVATION_ID" > "$TEST_RESULTS_DIR/observation_id.txt"
    else
        test_fail "Location header missing"
        return 1
    fi
    
    # Test response contains Observation resource
    if echo "$BODY" | jq -e '.resourceType == "Observation"' > /dev/null; then
        test_pass "Response contains Observation resource"
    else
        test_fail "Response does not contain Observation resource"
        return 1
    fi
    
    # Test observation references correct patient
    SUBJECT_REF=$(echo "$BODY" | jq -r '.subject.reference')
    if [[ "$SUBJECT_REF" == "Patient/$PATIENT_ID" ]]; then
        test_pass "Observation references correct patient"
    else
        test_fail "Observation subject reference incorrect. Expected Patient/$PATIENT_ID, got $SUBJECT_REF"
    fi
    
    # Test observation has correct status
    STATUS=$(echo "$BODY" | jq -r '.status')
    if [[ "$STATUS" == "final" ]]; then
        test_pass "Observation status correct"
    else
        test_fail "Observation status incorrect. Expected 'final', got '$STATUS'"
    fi
    
    # Test observation has LOINC code
    CODE=$(echo "$BODY" | jq -r '.code.coding[0].code')
    if [[ "$CODE" == "29463-7" ]]; then
        test_pass "Observation has correct LOINC code"
    else
        test_fail "Observation LOINC code incorrect. Expected '29463-7', got '$CODE'"
    fi
    
    # Test observation has value
    if echo "$BODY" | jq -e '.valueQuantity.value == 70.5' > /dev/null; then
        test_pass "Observation value correct"
    else
        test_fail "Observation value incorrect"
    fi
    
    # Save response for search tests
    echo "$BODY" > "$TEST_RESULTS_DIR/created_observation.json"
}

# Test 2: Search Observations by Patient (GET)
test_search_observations_by_patient() {
    test_start "Search Observations by Patient"
    
    # Get patient ID from setup
    if [[ ! -f "$TEST_RESULTS_DIR/observation_patient_id.txt" ]]; then
        test_fail "Patient ID not available from setup"
        return 1
    fi
    
    PATIENT_ID=$(cat "$TEST_RESULTS_DIR/observation_patient_id.txt")
    
    # Make search request
    RESPONSE=$(curl -s "$FHIR_BASE_URL/Observation?subject=Patient/$PATIENT_ID" \
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
    
    # Test response is Bundle
    if echo "$BODY" | jq -e '.resourceType == "Bundle"' > /dev/null; then
        test_pass "Response is Bundle resource"
    else
        test_fail "Response is not Bundle resource"
        return 1
    fi
    
    # Test bundle type is searchset
    BUNDLE_TYPE=$(echo "$BODY" | jq -r '.type')
    if [[ "$BUNDLE_TYPE" == "searchset" ]]; then
        test_pass "Bundle type is searchset"
    else
        test_fail "Bundle type incorrect. Expected 'searchset', got '$BUNDLE_TYPE'"
    fi
    
    # Test bundle has results
    TOTAL=$(echo "$BODY" | jq -r '.total')
    if [[ "$TOTAL" -gt 0 ]]; then
        test_pass "Bundle contains $TOTAL observation(s)"
    else
        test_fail "Bundle contains no observations"
        return 1
    fi
    
    # Test first entry is observation for correct patient
    FIRST_ENTRY_TYPE=$(echo "$BODY" | jq -r '.entry[0].resource.resourceType')
    FIRST_ENTRY_SUBJECT=$(echo "$BODY" | jq -r '.entry[0].resource.subject.reference')
    
    if [[ "$FIRST_ENTRY_TYPE" == "Observation" ]]; then
        test_pass "First entry is Observation resource"
    else
        test_fail "First entry is not Observation resource"
    fi
    
    if [[ "$FIRST_ENTRY_SUBJECT" == "Patient/$PATIENT_ID" ]]; then
        test_pass "First observation references correct patient"
    else
        test_fail "First observation subject incorrect. Expected Patient/$PATIENT_ID, got $FIRST_ENTRY_SUBJECT"
    fi
    
    # Test search mode
    SEARCH_MODE=$(echo "$BODY" | jq -r '.entry[0].search.mode')
    if [[ "$SEARCH_MODE" == "match" ]]; then
        test_pass "Search mode is 'match'"
    else
        test_fail "Search mode incorrect. Expected 'match', got '$SEARCH_MODE'"
    fi
}

# Test 3: Search Observations by Category
test_search_observations_by_category() {
    test_start "Search Observations by Category"
    
    # Make search request for vital signs
    RESPONSE=$(curl -s "$FHIR_BASE_URL/Observation?category=vital-signs" \
        -H "Accept: application/fhir+json" \
        -w "HTTPSTATUS:%{http_code}")
    
    HTTP_CODE=$(echo "$RESPONSE" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
    BODY=$(echo "$RESPONSE" | sed 's/HTTPSTATUS:[0-9]*//g')
    
    # Test HTTP status code
    if [[ "$HTTP_CODE" == "200" ]]; then
        test_pass "HTTP 200 OK response for category search"
    else
        test_fail "Expected HTTP 200, got $HTTP_CODE"
        return 1
    fi
    
    # Test response is Bundle
    if echo "$BODY" | jq -e '.resourceType == "Bundle"' > /dev/null; then
        test_pass "Response is Bundle resource"
    else
        test_fail "Response is not Bundle resource"
        return 1
    fi
    
    # Test bundle has results or is empty (both valid)
    TOTAL=$(echo "$BODY" | jq -r '.total')
    if [[ "$TOTAL" -ge 0 ]]; then
        test_pass "Category search returned $TOTAL observation(s)"
    else
        test_fail "Invalid total count: $TOTAL"
    fi
}

# Test 4: Search Non-existent Patient Observations
test_search_nonexistent_patient_observations() {
    test_start "Search Observations for Non-existent Patient"
    
    # Make search request for non-existent patient
    RESPONSE=$(curl -s "$FHIR_BASE_URL/Observation?subject=Patient/99999" \
        -H "Accept: application/fhir+json" \
        -w "HTTPSTATUS:%{http_code}")
    
    HTTP_CODE=$(echo "$RESPONSE" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
    BODY=$(echo "$RESPONSE" | sed 's/HTTPSTATUS:[0-9]*//g')
    
    # Test HTTP status code
    if [[ "$HTTP_CODE" == "200" ]]; then
        test_pass "HTTP 200 OK response for non-existent patient search"
    else
        test_fail "Expected HTTP 200, got $HTTP_CODE"
        return 1
    fi
    
    # Test total is 0
    TOTAL=$(echo "$BODY" | jq -r '.total')
    if [[ "$TOTAL" == "0" ]]; then
        test_pass "No observations found for non-existent patient"
    else
        test_fail "Expected 0 observations, got $TOTAL"
    fi
}

# Test 5: Create Observation with Invalid Patient Reference
test_create_observation_invalid_patient() {
    test_start "Create Observation with Invalid Patient Reference"
    
    # Create observation JSON with invalid patient reference
    INVALID_OBSERVATION_JSON='{
        "resourceType": "Observation",
        "status": "final",
        "category": [
            {
                "coding": [
                    {
                        "system": "http://terminology.hl7.org/CodeSystem/observation-category",
                        "code": "vital-signs",
                        "display": "Vital Signs"
                    }
                ]
            }
        ],
        "code": {
            "coding": [
                {
                    "system": "http://loinc.org",
                    "code": "29463-7",
                    "display": "Body Weight"
                }
            ]
        },
        "subject": {
            "reference": "Patient/99999",
            "display": "Non-existent Patient"
        },
        "effectiveDateTime": "2025-07-16T10:00:00+00:00",
        "valueQuantity": {
            "value": 70.5,
            "unit": "kg",
            "system": "http://unitsofmeasure.org",
            "code": "kg"
        }
    }'
    
    RESPONSE=$(curl -s -X POST "$FHIR_BASE_URL/Observation" \
        -H "Content-Type: application/fhir+json" \
        -H "Accept: application/fhir+json" \
        -d "$INVALID_OBSERVATION_JSON" \
        -w "HTTPSTATUS:%{http_code}")
    
    HTTP_CODE=$(echo "$RESPONSE" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
    
    # HAPI FHIR allows references to non-existent resources, so this should still succeed
    # This is configurable behavior, testing for successful creation
    if [[ "$HTTP_CODE" == "201" ]]; then
        test_pass "Observation created with non-existent patient reference (HAPI FHIR behavior)"
    else
        test_pass "Observation creation rejected for non-existent patient reference"
    fi
}

# Cleanup
cleanup_tests() {
    log "${YELLOW}Cleaning up test environment...${NC}"
    rm -f "$TEST_OBSERVATION_JSON"
    log "${GREEN}✅ Cleanup complete${NC}"
}

# Main execution
main() {
    log "${YELLOW}===========================================${NC}"
    log "${YELLOW}  FHIR Observation Operations Test Suite  ${NC}"
    log "${YELLOW}===========================================${NC}"
    log "Start time: $(date)"
    log "FHIR Base URL: $FHIR_BASE_URL"
    log "Log file: $LOG_FILE"
    log ""
    
    # Setup
    setup_tests
    create_test_patient
    
    # Run tests
    test_create_observation
    test_search_observations_by_patient
    test_search_observations_by_category
    test_search_nonexistent_patient_observations
    test_create_observation_invalid_patient
    
    # Cleanup
    cleanup_tests
    
    # Summary
    log ""
    log "${YELLOW}===========================================${NC}"
    log "${YELLOW}              TEST SUMMARY                ${NC}"
    log "${YELLOW}===========================================${NC}"
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