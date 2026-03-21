import CommonCrypto
import CryptoKit
import Foundation
import Security

public enum WorkspaceExportError: Error {
    case invalidEnvelope
    case invalidCiphertext
    case keyDerivationFailed
}

private struct ExportEnvelope: Codable {
    struct KDF: Codable {
        struct Params: Codable {
            let iterations: Int
        }
        let name: String
        let salt_b64: String
        let params: Params
    }

    struct Cipher: Codable {
        let name: String
        let nonce_b64: String
        let ciphertext_b64: String
    }

    let format_version: Int
    let kdf: KDF
    let cipher: Cipher
}

public final class WorkspaceExporter {
    public init() {}

    public func export(graph: WorkspaceGraph, passphrase: String) throws -> Data {
        let salt = randomData(count: 16)
        let nonce = AES.GCM.Nonce()
        let key = try deriveKey(passphrase: passphrase, salt: salt, iterations: 100_000)
        let payload = try JSONEncoder.amon.encode(graph)
        let sealed = try AES.GCM.seal(payload, using: key, nonce: nonce)
        var combined = Data()
        combined.append(sealed.ciphertext)
        combined.append(sealed.tag)
        let envelope = ExportEnvelope(
            format_version: 1,
            kdf: .init(name: "pbkdf2-hmac-sha256", salt_b64: salt.base64EncodedString(), params: .init(iterations: 100_000)),
            cipher: .init(name: "aes-256-gcm", nonce_b64: nonce.data.base64EncodedString(), ciphertext_b64: combined.base64EncodedString())
        )
        return try JSONEncoder.amon.encode(envelope)
    }

    public func `import`(data: Data, passphrase: String) throws -> WorkspaceGraph {
        let envelope = try JSONDecoder.amon.decode(ExportEnvelope.self, from: data)
        guard envelope.format_version == 1,
              envelope.kdf.name == "pbkdf2-hmac-sha256",
              envelope.cipher.name == "aes-256-gcm",
              let salt = Data(base64Encoded: envelope.kdf.salt_b64),
              let nonceData = Data(base64Encoded: envelope.cipher.nonce_b64),
              let ciphertextAndTag = Data(base64Encoded: envelope.cipher.ciphertext_b64)
        else {
            throw WorkspaceExportError.invalidEnvelope
        }

        let key = try deriveKey(passphrase: passphrase, salt: salt, iterations: envelope.kdf.params.iterations)
        let nonce = try AES.GCM.Nonce(data: nonceData)
        guard ciphertextAndTag.count >= 16 else { throw WorkspaceExportError.invalidCiphertext }
        let ciphertext = Data(ciphertextAndTag.dropLast(16))
        let tag = Data(ciphertextAndTag.suffix(16))
        let sealed = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
        let decrypted = try AES.GCM.open(sealed, using: key)
        return try JSONDecoder.amon.decode(WorkspaceGraph.self, from: decrypted)
    }

    private func deriveKey(passphrase: String, salt: Data, iterations: Int) throws -> SymmetricKey {
        let passwordData = Data(passphrase.utf8)
        var derived = Data(count: 32)
        let result = derived.withUnsafeMutableBytes { derivedBytes in
            salt.withUnsafeBytes { saltBytes in
                passwordData.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.bindMemory(to: Int8.self).baseAddress,
                        passwordData.count,
                        saltBytes.bindMemory(to: UInt8.self).baseAddress,
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        derivedBytes.bindMemory(to: UInt8.self).baseAddress,
                        32
                    )
                }
            }
        }
        guard result == kCCSuccess else { throw WorkspaceExportError.keyDerivationFailed }
        return SymmetricKey(data: derived)
    }

    private func randomData(count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes)
    }
}

private extension AES.GCM.Nonce {
    var data: Data {
        withUnsafeBytes { Data($0) }
    }
}
