import XCTest
@testable import Slide

import KeychainLinux
import KeychainTypes

final class SlideTests: XCTestCase
{
    func testKeys() throws
    {
        let privateKey = try PrivateKey(type: .P256KeyAgreement)
        let publicKey = privateKey.publicKey

        let encoder = JSONEncoder()
        let data = try encoder.encode(publicKey)
        print(data.string)
    }
}
