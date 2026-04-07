import Foundation

extension String {
    /// Convert a two-letter country code (e.g. "us") to its emoji flag (e.g. "🇺🇸").
    ///
    /// Uses Unicode Regional Indicator Symbols. Each letter A-Z maps to a regional
    /// indicator symbol, and two consecutive indicators form a flag emoji.
    var countryFlag: String {
        let uppercased = self.uppercased()
        guard uppercased.count == 2,
              uppercased.unicodeScalars.allSatisfy({ $0.value >= 0x41 && $0.value <= 0x5A })
        else {
            return "🏳️"
        }

        let base: UInt32 = 0x1F1E6 - 0x41 // Regional Indicator 'A' minus ASCII 'A'
        let flags = uppercased.unicodeScalars.map { Unicode.Scalar(base + $0.value)! }
        return String(flags.map { Character($0) })
    }
}
