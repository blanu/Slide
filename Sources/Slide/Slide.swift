//
//  Slide.swift
//  
//
//  Created by Dr. Brandon Wiley on 11/29/22.
//

import Foundation

import Crypto
import Datable
import Gardener
import KeychainLinux
import KeychainTypes

public struct Slide
{
    static public func getPublicKey(keychain: Keychain) throws -> String
    {
        guard let privateKey = keychain.retrieveOrGeneratePrivateKey(label: "Slide", type: .P256KeyAgreement) else
        {
            throw SlideError.couldNotLoadPrivateKey
        }

        let publicKey = privateKey.publicKey
        guard let publicKeyString = publicKey.string else
        {
            throw SlideError.publicKeyStringConversionError
        }

        return publicKeyString
    }

    public struct Encrypter
    {
        let receiverPublicKey: PublicKey
        let senderPrivateKey: PrivateKey

        public init(keychain: Keychain, receiverPublicKeyString: String) throws
        {
            self.receiverPublicKey = try PublicKey(string: receiverPublicKeyString)

            guard let senderPrivateKey = keychain.retrieveOrGeneratePrivateKey(label: "Slide", type: .P256KeyAgreement) else
            {
                throw SlideError.couldNotLoadPrivateKey
            }

            self.senderPrivateKey = senderPrivateKey
        }

        public func encrypt(_ message: String) throws -> String
        {
            let sharedSecret = try self.senderPrivateKey.sharedSecretFromKeyAgreement(with: self.receiverPublicKey)
            let sharedKey = sharedSecret.x963DerivedSymmetricKey(using: SHA256.self, sharedInfo: Data(), outputByteCount: 32)
            let nonce = AES.GCM.Nonce()
            let sealedBox = try SealedBox(type: .AESGCM, nonce: .AESGCM(nonce), key: sharedKey, dataToSeal: message.data)
            guard let sealedBoxString = sealedBox.string else
            {
                throw SlideError.sealedBoxStringEncodingFailure
            }
            return sealedBoxString
        }
    }

    public struct Decrypter
    {
        let senderPublicKey: PublicKey
        let receiverPrivateKey: PrivateKey

        public init(keychain: Keychain, senderPublicKeyString: String) throws
        {
            self.senderPublicKey = try PublicKey(string: senderPublicKeyString)

            guard let receiverPrivateKey = keychain.retrieveOrGeneratePrivateKey(label: "Slide", type: .P256KeyAgreement) else
            {
                throw SlideError.couldNotLoadPrivateKey
            }

            self.receiverPrivateKey = receiverPrivateKey
        }

        public func decrypt(_ message: String) throws -> String
        {
            let sharedSecret = try self.receiverPrivateKey.sharedSecretFromKeyAgreement(with: self.senderPublicKey)
            let sharedKey = sharedSecret.x963DerivedSymmetricKey(using: SHA256.self, sharedInfo: Data(), outputByteCount: 32)
            let sealedBox = try SealedBox(string: message)
            let resultData = try sealedBox.open(key: sharedKey)
            return resultData.string
        }
    }
}

public enum SlideError: Error
{
    case couldNotLoadPrivateKey
    case couldNotOpenKeychain
    case publicKeyStringConversionError
    case sealedBoxHasNoData
    case sealedBoxStringEncodingFailure
}
