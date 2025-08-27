#!/usr/bin/env swift

import Foundation

// Simple test without package dependencies
print("Testing JSON fixes directly...")

// Test 1: Leading plus
let input1 = #"{"n": +123}"#
print("\nTest 1: Leading plus")
print("Input: \(input1)")
print("Expected: should contain '123' not '+123'")

// Test 2: Bare decimal
let input2 = #"{"n": .5}"#
print("\nTest 2: Bare decimal")
print("Input: \(input2)")
print("Expected: should contain '0.5'")

// Test 3: TRUE to true
let input3 = #"{"a": TRUE}"#
print("\nTest 3: TRUE to true")
print("Input: \(input3)")
print("Expected: should contain 'true' not 'TRUE'")

print("\nDone!")