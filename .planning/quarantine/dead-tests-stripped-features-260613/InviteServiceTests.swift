import XCTest
@testable import workload_management

final class InviteServiceTests: XCTestCase {

    // MARK: - Code generation

    func test_generateCode_returns6CharAlphanumeric() {
        let code = InviteService.makeLocalCode()
        XCTAssertEqual(code.count, 6)
        XCTAssertTrue(code.allSatisfy { $0.isLetter || $0.isNumber })
        XCTAssertTrue(code.allSatisfy { $0.isUppercase || $0.isNumber })
    }

    func test_generateCode_isRandom() {
        let codes = Set((0..<20).map { _ in InviteService.makeLocalCode() })
        XCTAssertGreaterThan(codes.count, 1)
    }

    // MARK: - Deep link parsing

    func test_handleDeepLink_validURL_returnsCode() {
        let url = URL(string: "workload://invite?code=ABC123")!
        let code = InviteService.handleDeepLink(url)
        XCTAssertEqual(code, "ABC123")
    }

    func test_handleDeepLink_missingCode_returnsNil() {
        let url = URL(string: "workload://invite")!
        let code = InviteService.handleDeepLink(url)
        XCTAssertNil(code)
    }

    func test_handleDeepLink_wrongScheme_returnsNil() {
        let url = URL(string: "https://example.com/invite?code=ABC123")!
        let code = InviteService.handleDeepLink(url)
        XCTAssertNil(code)
    }

    func test_handleDeepLink_wrongHost_returnsNil() {
        let url = URL(string: "workload://other?code=ABC123")!
        let code = InviteService.handleDeepLink(url)
        XCTAssertNil(code)
    }
}
