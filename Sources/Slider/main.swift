//
//  Slider.swift
//  
//
//  Created by Dr. Brandon Wiley on 11/29/22.
//

import ArgumentParser
import Foundation

import Datable
import Gardener
import KeychainLinux
import KeychainTypes

import Slide

struct Slider: ParsableCommand
{
    static let configuration = CommandConfiguration(
        commandName: "slider",
        subcommands: [Encrypt.self, Decrypt.self, Display.self]
    )
}

extension Slider
{
    struct Encrypt: ParsableCommand
    {
        @Argument(help: "the public key of the receiver in Slide format")
        var receiverPublicKeyString: String

        @Argument(help: "the message to encrypt")
        var message: String?

        @Option(name: .shortAndLong, help: "the file containing the message to encrypt")
        var inputFilename: String?

        @Option(name: .shortAndLong, help: "the file to write the encrypted message")
        var outputFilename: String?

        mutating public func run() throws
        {
            let homeDirectory = File.homeDirectory()
            let slideDirectory = homeDirectory.appendingPathComponent(".slide")
            guard let keychain = Keychain(baseDirectory: slideDirectory) else
            {
                throw SlideError.couldNotOpenKeychain
            }

            if (message == nil) && (inputFilename == nil)
            {
                print("You must specify either a message or an input filename.")
                return
            }

            if (message != nil) && (inputFilename != nil)
            {
                print("You cannot specify both a message and an input filename.")
                return
            }

            let inputMessage: String
            if let inputFilename = inputFilename
            {
                let url = URL(fileURLWithPath: inputFilename)
                let data = try Data(contentsOf: url)
                inputMessage = data.string
            }
            else if let message = message
            {
                inputMessage = message
            }
            else
            {
                return
            }

            let encrypter = try Slide.Encrypter(keychain: keychain, receiverPublicKeyString: receiverPublicKeyString)
            let encrypted = try encrypter.encrypt(inputMessage)

            if let outputFilename = outputFilename
            {
                let outputData = encrypted.data
                let outputURL = URL(fileURLWithPath: outputFilename)
                try outputData.write(to: outputURL)
            }
            else
            {
                print(encrypted)
            }
        }
    }
}

extension Slider
{
    struct Decrypt: ParsableCommand
    {
        @Argument(help: "the public key of the receiver in Slide format")
        var senderPublicKeyString: String

        @Argument(help: "the message to encrypt")
        var message: String?

        @Option(name: .shortAndLong, help: "the file containing the message to encrypt")
        var inputFilename: String?

        @Option(name: .shortAndLong, help: "the file to write the encrypted message")
        var outputFilename: String?

        mutating public func run() throws
        {
            let homeDirectory = File.homeDirectory()
            let slideDirectory = homeDirectory.appendingPathComponent(".slide")
            guard let keychain = Keychain(baseDirectory: slideDirectory) else
            {
                throw SlideError.couldNotOpenKeychain
            }

            if (message == nil) && (inputFilename == nil)
            {
                print("You must specify either a message or an input filename.")
                return
            }

            if (message != nil) && (inputFilename != nil)
            {
                print("You cannot specify both a message and an input filename.")
                return
            }

            let inputMessage: String
            if let inputFilename = inputFilename
            {
                let url = URL(fileURLWithPath: inputFilename)
                let data = try Data(contentsOf: url)
                inputMessage = data.string
            }
            else if let message = message
            {
                inputMessage = message
            }
            else
            {
                return
            }

            let decrypter = try Slide.Decrypter(keychain: keychain, senderPublicKeyString: senderPublicKeyString)
            let decrypted = try decrypter.decrypt(inputMessage)

            if let outputFilename = outputFilename
            {
                let outputData = decrypted.data
                let outputURL = URL(fileURLWithPath: outputFilename)
                try outputData.write(to: outputURL)
            }
            else
            {
                print(decrypted)
            }
        }
    }
}

extension Slider
{
    struct Display: ParsableCommand
    {
        mutating public func run() throws
        {
            let homeDirectory = File.homeDirectory()
            let slideDirectory = homeDirectory.appendingPathComponent(".slide")
            guard let keychain = Keychain(baseDirectory: slideDirectory) else
            {
                throw SlideError.couldNotOpenKeychain
            }

            let publicKey = try Slide.getPublicKey(keychain: keychain)
            print(publicKey)
        }
    }
}


Slider.main()
