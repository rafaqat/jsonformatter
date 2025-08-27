# ParseTreeJSONFixer Deep Analysis

## Critical Correctness Issues Found

### 1. 🔴 **String Escaping is Incomplete**
**Location:** `JSONNode.swift:68-75` and `ParseTreeJSONFixer.swift:1185`

**Current Implementation:**
```swift
var escapedJSON: String {
    self
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
        .replacingOccurrences(of: "\n", with: "\\n")
        .replacingOccurrences(of: "\r", with: "\\r")
        .replacingOccurrences(of: "\t", with: "\\t")
}
```

**Problems:**
- Missing control characters: `\b` (backspace), `\f` (form feed), and others < 0x20
- No Unicode escape for non-printable characters
- ParseTreeJSONFixer doesn't even use this escaping!

**Impact:** Produces **INVALID JSON** when strings contain control characters

### 2. 🔴 **No Unicode/Surrogate Pair Support**
**Location:** `ParseTreeJSONFixer.swift:640-670`

**Problems:**
- parseString doesn't handle `\uXXXX` escape sequences
- No support for surrogate pairs (emoji as `\uD83D\uDE00`)
- Can't parse valid JSON with Unicode escapes

**Impact:** **FAILS** to parse valid JSON with Unicode escapes

### 3. 🟡 **Number Precision Loss**
**Location:** `ParseTreeJSONFixer.swift:693-736`

**Current:** All numbers stored as `Double`
```swift
enum Token {
    case number(Double)
}
```

**Problems:**
- Large integers (>2^53) lose precision
- Original format lost (1.0 becomes 1, 1e2 becomes 100)
- No preservation of -0 vs 0

**Impact:** Data corruption for large integers, format changes

### 4. 🔴 **ParseTreeJSONFixer Output Not Escaped**
**Location:** `ParseTreeJSONFixer.swift:1185, 1209`

```swift
// Keys not escaped!
result += nextIndentStr + "\"\(member.key)\": "

// String values not escaped!
case .string(let str, _):
    return "\"\(str)\""
```

**Impact:** **PRODUCES INVALID JSON** if strings contain quotes or control chars

## How the Parser Works

### Tokenization Phase
1. Scans character by character
2. Identifies structural tokens: `{}[],:` 
3. Parses strings (but incompletely)
4. Parses numbers (as Double)
5. Handles unterminated strings

### Parse Tree Building
1. Recursive descent parser
2. Error recovery for missing delimiters
3. Tracks unterminated structures
4. Handles trailing commas

### Reconstruction Phase
1. Walks parse tree
2. Outputs formatted JSON
3. **BUG: No escaping applied!**

## Error Recovery Mechanisms

### Current Strengths
✅ Handles unterminated strings
✅ Detects missing brackets/braces
✅ Fixes trailing commas
✅ Wraps multiple root objects
✅ Handles unquoted keys

### Current Weaknesses
❌ Can't recover from Unicode errors
❌ No context preservation for numbers
❌ String escaping broken
❌ Can't handle mixed quotes properly

## Performance Concerns

- Multiple string allocations
- Character-by-character scanning
- No streaming support
- Won't scale to 100MB files

## Recommendations

### Immediate Fixes Needed
1. **Fix string escaping** - Add proper Unicode escape handling
2. **Use escaping in output** - Apply escapedJSON to all string outputs
3. **Add surrogate pair support** - Handle emoji and BMP characters
4. **Preserve number format** - Store original lexeme

### Longer Term
1. Add streaming tokenizer for large files
2. Preserve object key order
3. Add configurable fix strategies
4. Improve error messages with positions