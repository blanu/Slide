# Slide
## End-to-end Encrypted Messaging for ActivityPub

Author: Dr. Brandon Wiley <@brandon@blanu.net>

Implementation: [https://github.com/blanu/Slide](https://github.com/blanu/Slide) - [https://github.com/blanu/toot](https://github.com/blanu/toot)

# Introduction

ActivityPub services such as Mastodon lack end-to-end encrypted direct messages (DMs). Slide is a proposed cryptographic protocol and message format for integrating end-to-end encrypted direct messages into 
ActivityPub clients in a way that is compatible with existing servers.

# Motivation

End-to-end encrypted direct messaging is necessary for the security and privacy of private messages. The best way to ensure privacy is to encrypt on the clients. As the server is not involved in the encrypted 
process, no modifications to the server are necessary as long as the encrypted messages are sent in a format that is compatible with legacy non-encrypted direct messages.

# Proposed Solution

End-to-end encrypted messaging without modification to the server can be done by specifying an encoding for encrypted messages that is compatible with existing messages. The proposed solution is to put the 
encoded message in the body of the post in the form of a special "slide:" URI. This will allow clients that are familiar with the Slide protocol to decrypt the messages and display the decrypted text, along 
with an indicator that the message was encrypted. In clients that do not implement the Slide protocol, the encrypted messages will show up, but not be decrypted, which is the correct behavior for clients that 
do not have access to the user's private key.

For sharing key information, the user's profile metadata can be used. Mastodon allows for freeform fields, so one of these can be used to store and make public the user's public key. Users sending or 
receiving a slide message can look up the other party's public key by looking up their profile information.

# Design

## Private Key

Private keys are P-256 elliptic curve private keys. The storage format of private keys is not part of the cryptographic protocol since private keys are never shared, but the recommendation is to store them in 
binary SEC1 format, also known as 'raw' format. Since users should never see or touch these keys, they do not need to be in a human-readable format.

## Public Keys

Public keys are P-256 elliptic curve public keys. They are stored in the following format:
-   1 byte - The number 2 (0x02) to indicate a P-256 key
-   32 bytes - The key in SEC1 format, also known as 'raw' format  

These bytes are encode into Base64 to form a human-readable value to be shared.

## Key Exchange

In order to participate in Slide end-to-end encrypted messaging, the user adds their public key to their profile metadata fields with the name "P-256 public key" and their base64-encoded public key as the 
value.

When sending a message, the sender must first retrieve the receiver's key. This is done by fetching the receiver's account profile and looking in the "fields" section of the Account object. This contains a 
list of dictionaries where each dictionary contains an entry with the "name" key and one with the "value" key. In order to find the user's key, the fields are searched for an item that has "P-256 public key" 
for "name" field. Once this item is found, the value associated with the "value" field holds the receiver's base64-encoded public key.

When receiving a message, the same procedure is listed above is done in order to find the sender's key.

## Shared Encryption Key Agreement

Once user's private key has been loaded and the other party's public key has been retrieved from their account profile, a Elliptic Curve Diffe-Helman (ECDH) key exchange is performed with the two keys. The 
resulting shared secret is then used as input to the X9.63 key derivation function. The output is the encryption key. 

## Encryption

Messages are encrypted using the AES cipher in GCM mode using a random nonce. The nonce is prepended to the ciphertext and the authentication tag is appended. So the output looks like this:

| Nonce | Ciphertext | Tag |
|-------|------------|-----|
| 16 bytes | variable length | 16 bytes |

## Message Format

An unencrypted DM have the following format:  

``@username@instance message``

Example:

``@user@example.com Hi! This is a message!``

Slide messages have the following format:  

``@username@instance slide:encrypted``

where the encrypted message is the base64-encoded output of the encryption step.

Example:

``@user@example.com slide:AtXSht3SJwzo7jI7FUjmUzwHA7DgLHscHBY6HJcQ7K6v``

## Decryption

When receiving a message, split the user from the encrypted message by splitting the message text on the first space. Then look at the message text to see if the message starts with "slide:". If so, then the 
rest of the message is the base64-encoded encrypted text. Base64 decode the encrypted text for decryption.

Next, look up the sender's public key using the procedure in the "Key Exchange" section. Base64 decode the sender's public key and load the user's private key. Then perform a ECDH key exchange as specified in 
the "Shared Encryption Key Agreement" section. Decrypt the encrypted text with AES in GCM mode. The encrypted text consists of nonce, ciphertext, and authentication tag parts as specified in the "Encryption" 
section. Decrypting the encrypted text results in the decrypted text.

To recreate the original message, concatenate the user with the decrypted text. Optionally, in order to indicate that the message was encrypted, the implementation may prepend the text "\[Encrypted with 
Slide\] ". Other user interface elements to indicate that the message was encrypted are equally acceptable. The optional text modification is just a suggestion. So the final message will look like this:

``@username@instance message``

Example:

``@user@example.com Hi! This is a message!``

Or optionally:

``[Encrypted with Slide] @username@instance message``

Example:

``[Encrypted with Slide] @user@example.com Hi! This is a message!``

# Alternatives Considered

Encrypted messages could be added as a first-class entity in the ActivityPub specification such that the clients supporting the specification deal with encrypted messages directly instead of embedding them in 
other messages. This is a fine idea if someone would like to put in the time, but we need something to use in the meantime.  

Making other cryptographic protocols are possible, from PGP to OTR. The benefit of Slide over these other protocols is simplicity. It only uses commonly available cryptographic primitives and minimalist 
formats. In particular, it does not require an ASN.1 parser.

# Addendum

## Implementation

The proof-of-concept implementation is split into two parts. The cryptography is implemented in a helper application called "slider". This is part of the Slide library and implemented in Swift. The Mastodon 
integration is done using a custom fork of the "toot" client for Python. It calls the slider application to do the cryptography. A precompiled binary of slider for the macOS operating system and the M1 
process is included in the toot fork. To use the proof-of-concept demonstration, checkout toot. If you need to compile a different version of slider, then also checkout Slide, compile it, and then move the 
binary into the toot folder. Once you have toot checked out and slider in the right place, follow these steps to see Slide in action:

Install toot:
``python3 setup.py install``

Get your public key:
``./slider display``  

Copy the output, this is your public key.

Edit your Mastodon profile and under "Profile metadata" add a field with the name "P-256 public key" and for the value paste in your public key.  

Send an encrypted message:
``toot post -v encrypted``

Type your message. Make sure to include a username, as is required for a direct message:

``@user@example.com Hi! This is an encrypted message!``  

toot requires you to press Ctrl-D to end the message.

If the recipient has also added their public key to their profile, you should have now sent them an encrypted message. Once they send you one back, you can check your timeline:

``toot timeline``
  
Any encrypted messages should be marked with "\[Encrypted with Slide\]".

## Explanation of Cryptographic Operations

The P-256 elliptic curve (EC) is used for generating the shared secret by means of elliptic curve Diffie-Helman (ECDH) key agreement. P-256 was chosen because it is common to all platforms and does not require 
additional libraries. On iOS and macOS devices, only P-256 keys can be stored in the Secure Enclave, making it the most suitable choice of curve in terms of being commonly available and well-supported. On 
Android, unfortunately, most devices do not have a secure enclave and for many versions of Android the KeyStore can only do public key operations for RSA keys. While newer versions of Android documentation 
states support for elliptic curve keys in the KeyStore, those are only signing keys and cannot be used for ECDH key agreement. Even if Android does eventually support EC keys in the KeyStore, since most 
Android devices use older versions, the only practical option for using the KeyStore on Android is to use RSA keys. As these are no longer considered a good option according to cryptography best practices, 
compatibility with the Android KeyStore was eliminated from consideration as a criteria. Many cryptographers also have their own opinions about which curves are best and not everyone prefers P-256 keys. 
However, no actual attacks have been demonstrated to show that P-256 keys are insecure. Therefore, due to common availability and Secure Enclave support on Apple devices, they are the most suitable choice at 
this time.

The AES-256 cipher in GCM mode, supporting “authenticated encryption with associated data” (AEAD) is used as the encryption cipher. This is a commonly available cipher that is available on all platforms and 
the GCM mode is preferred because it supports AEAD. It is also commonly supported by hardware accelerated operation on several platforms. Many cryptographers also have their own opinions about which ciphers 
are best and not everyone prefers AES. However, no actual attacks have been demonstrated to show that AES is insecure. Therefore, due to common availability, it is the most suitable choice at this time.

For key derivation, the X9.63 key derivation function was chosen because it is one that is commonly available and does not require adding additional information to the message. The most obvious alternative, 
HKDF, requires adding salt to the message. As X9.63 is not an open standard, it would be preferable to use a different key derivation function in future versions of the protocol if a suitable alternative is 
found that is also widely available.
