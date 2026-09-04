import XCTest
@testable import CodexBellCore

final class AppServerNotificationDecoderTests: XCTestCase {
    func testTurnCompletedStatusesMapToCoreEvents() throws {
        for (status, kind) in [("completed", CodexEventKind.stop), ("failed", .turnFailed), ("interrupted", .interrupt)] {
            let json = "{\"method\":\"turn/completed\",\"params\":{\"threadId\":\"thread-1\",\"turn\":{\"id\":\"turn-1\",\"status\":\"\(status)\"}}}"
            let data = Data(json.utf8)
            let event = try XCTUnwrap(AppServerNotificationDecoder.decode(data))
            XCTAssertEqual(event.kind, kind)
            XCTAssertEqual(event.turnID, "turn-1")
            XCTAssertEqual(event.sessionID, "thread-1")
        }
    }

    func testUnrelatedNotificationReturnsNil() throws {
        let data = Data(#"{"method":"item/started","params":{}}"#.utf8)
        XCTAssertNil(try AppServerNotificationDecoder.decode(data))
    }
}
