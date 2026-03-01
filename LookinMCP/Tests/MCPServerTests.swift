import XCTest
@testable import MCPServer

final class MCPServerTests: XCTestCase {
    
    func testJSONValueParsing() throws {
        let json = """
        {"name": "test", "value": 42, "enabled": true}
        """
        
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        
        XCTAssertEqual(decoded["name"]?.stringValue, "test")
        XCTAssertEqual(decoded["value"]?.intValue, 42)
        XCTAssertEqual(decoded["enabled"]?.boolValue, true)
    }
    
    func testJSONRPCRequestParsing() throws {
        let json = """
        {"jsonrpc": "2.0", "id": 1, "method": "tools/list", "params": {}}
        """
        
        let data = Data(json.utf8)
        let request = try JSONDecoder().decode(JSONRPCRequest.self, from: data)
        
        XCTAssertEqual(request.jsonrpc, "2.0")
        XCTAssertEqual(request.method, "tools/list")
        
        if case .number(let id) = request.id {
            XCTAssertEqual(id, 1)
        } else {
            XCTFail("Expected numeric ID")
        }
    }
    
    func testJSONRPCResponseEncoding() throws {
        let response = JSONRPCResponse(
            id: .number(1),
            result: ["status": "ok"]
        )
        
        let data = try JSONEncoder().encode(response)
        let json = String(data: data, encoding: .utf8)!
        
        XCTAssertTrue(json.contains("\"jsonrpc\":\"2.0\""))
        XCTAssertTrue(json.contains("\"id\":1"))
        XCTAssertTrue(json.contains("\"status\":\"ok\""))
    }
}
