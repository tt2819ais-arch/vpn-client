import XCTest
@testable import VPNClient

final class SmokeTests: XCTestCase {
    func testBundledServersHaveExpectedShape() {
        let servers = Server.bundled
        XCTAssertEqual(servers.count, 3)
        XCTAssertEqual(servers[0].port, 443)
        XCTAssertEqual(servers[1].port, 4443)
        XCTAssertEqual(servers[2].port, 2096)
        XCTAssertEqual(servers[2].routing, .bypassWhitelist)
    }

    func testXrayConfigContainsExpectedKeys() throws {
        let server = Server.bundled[0]
        let dataDir = FileManager.default.temporaryDirectory
        let json = try XrayConfigBuilder.jsonString(for: server, dataDir: dataDir)
        XCTAssertTrue(json.contains("\"vless\""))
        XCTAssertTrue(json.contains(server.publicKey))
        XCTAssertTrue(json.contains(server.serverName))
    }

    func testBypassRoutingIncludesWhitelist() throws {
        let server = Server.bundled[2]
        let dataDir = FileManager.default.temporaryDirectory
        let dict = XrayConfigBuilder.build(for: server, dataDir: dataDir)
        let routing = try XCTUnwrap(dict["routing"] as? [String: Any])
        let rules = try XCTUnwrap(routing["rules"] as? [[String: Any]])
        XCTAssertTrue(rules.contains { rule in
            (rule["outboundTag"] as? String) == "direct"
        })
    }

    func testPingResultProbeURL() {
        XCTAssertEqual(PingResult.probeURL.absoluteString, "https://www.gstatic.com/generate_204")
    }
}
