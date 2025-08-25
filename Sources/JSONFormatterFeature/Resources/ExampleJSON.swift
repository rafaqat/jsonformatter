import Foundation

public struct ExampleJSON {
    static let examples: [(name: String, json: String)] = [
        ("Simple Object", """
        {
          "name": "John Doe",
          "age": 30,
          "email": "john.doe@example.com",
          "isActive": true
        }
        """),
        
        ("User Profile", """
        {
          "user": {
            "id": "12345",
            "username": "johndoe",
            "profile": {
              "firstName": "John",
              "lastName": "Doe",
              "avatar": "https://example.com/avatar.jpg",
              "bio": "Software developer passionate about Swift and macOS",
              "location": {
                "city": "San Francisco",
                "state": "CA",
                "country": "USA",
                "coordinates": {
                  "latitude": 37.7749,
                  "longitude": -122.4194
                }
              }
            },
            "settings": {
              "theme": "dark",
              "notifications": true,
              "language": "en-US",
              "timezone": "America/Los_Angeles"
            },
            "createdAt": "2024-01-15T10:30:00Z",
            "lastLogin": "2024-08-23T14:25:00Z"
          }
        }
        """),
        
        ("Product Catalog", """
        {
          "products": [
            {
              "id": 1,
              "name": "MacBook Pro 16-inch",
              "category": "Laptops",
              "price": 2499.99,
              "currency": "USD",
              "inStock": true,
              "specs": {
                "processor": "M3 Max",
                "memory": "32GB",
                "storage": "1TB SSD",
                "display": "16.2-inch Liquid Retina XDR"
              },
              "tags": ["professional", "high-performance", "apple-silicon"]
            },
            {
              "id": 2,
              "name": "Magic Mouse",
              "category": "Accessories",
              "price": 99.00,
              "currency": "USD",
              "inStock": true,
              "specs": {
                "connectivity": "Bluetooth",
                "battery": "Rechargeable",
                "color": "White"
              },
              "tags": ["wireless", "ergonomic"]
            },
            {
              "id": 3,
              "name": "AirPods Pro",
              "category": "Audio",
              "price": 249.00,
              "currency": "USD",
              "inStock": false,
              "specs": {
                "type": "In-ear",
                "noiseCancellation": true,
                "batteryLife": "6 hours"
              },
              "tags": ["wireless", "noise-cancelling", "portable"]
            }
          ]
        }
        """),
        
        ("API Response", """
        {
          "status": "success",
          "code": 200,
          "data": {
            "users": [
              {
                "id": 1,
                "name": "Alice Johnson",
                "role": "admin",
                "permissions": ["read", "write", "delete"]
              },
              {
                "id": 2,
                "name": "Bob Smith",
                "role": "editor",
                "permissions": ["read", "write"]
              },
              {
                "id": 3,
                "name": "Charlie Brown",
                "role": "viewer",
                "permissions": ["read"]
              }
            ],
            "pagination": {
              "page": 1,
              "perPage": 20,
              "total": 3,
              "totalPages": 1
            }
          },
          "timestamp": "2024-08-23T15:30:00Z"
        }
        """),
        
        ("Geographic Data", """
        {
          "locations": [
            {
              "name": "Apple Park",
              "address": "One Apple Park Way, Cupertino, CA",
              "coordinates": {
                "lat": 37.3349,
                "lng": -122.0090
              },
              "type": "headquarters"
            },
            {
              "name": "Golden Gate Bridge",
              "address": "Golden Gate Bridge, San Francisco, CA",
              "coordinates": {
                "lat": 37.8199,
                "lng": -122.4783
              },
              "type": "landmark"
            },
            {
              "name": "Alcatraz Island",
              "address": "Alcatraz Island, San Francisco, CA",
              "coordinates": {
                "lat": 37.8267,
                "lng": -122.4230
              },
              "type": "historic"
            }
          ]
        }
        """),
        
        ("Complex Nested", """
        {
          "company": "TechCorp Inc.",
          "founded": 2010,
          "departments": [
            {
              "name": "Engineering",
              "headCount": 150,
              "teams": [
                {
                  "name": "iOS Development",
                  "members": 12,
                  "projects": ["Mobile App", "SDK Development"],
                  "technologies": ["Swift", "SwiftUI", "Combine"]
                },
                {
                  "name": "Backend",
                  "members": 20,
                  "projects": ["API Gateway", "Microservices"],
                  "technologies": ["Go", "PostgreSQL", "Redis"]
                }
              ]
            },
            {
              "name": "Marketing",
              "headCount": 30,
              "campaigns": [
                {
                  "name": "Summer Launch",
                  "budget": 50000,
                  "channels": ["social", "email", "web"]
                }
              ]
            }
          ],
          "financials": {
            "revenue": 10000000,
            "profit": 2500000,
            "quarters": [
              {"q": "Q1", "revenue": 2000000},
              {"q": "Q2", "revenue": 2500000},
              {"q": "Q3", "revenue": 2700000},
              {"q": "Q4", "revenue": 2800000}
            ]
          }
        }
        """),
        
        ("Invalid JSON (for testing)", """
        {
          name: "Missing quotes",
          'singleQuotes': 'not valid',
          "trailingComma": true,
          "comments": "JSON doesn't support comments", // but people try
          "unquotedNumbers": 0123,
        }
        """),
        
        ("Geographic Locations", """
        {
          "locations": [
            {
              "name": "Statue of Liberty",
              "city": "New York",
              "latitude": 40.6892,
              "longitude": -74.0445
            },
            {
              "name": "Golden Gate Bridge",
              "city": "San Francisco",
              "lat": 37.8199,
              "lng": -122.4783
            },
            {
              "name": "Eiffel Tower",
              "place": "Paris",
              "coordinates": {
                "lat": 48.8584,
                "lon": 2.2945
              }
            },
            {
              "name": "Sydney Opera House",
              "location": {
                "latitude": -33.8568,
                "longitude": 151.2153
              }
            },
            {
              "name": "Tokyo Tower",
              "coordinates": [139.7454, 35.6586]
            }
          ]
        }
        """)
    ]
}