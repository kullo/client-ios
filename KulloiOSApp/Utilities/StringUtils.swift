/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

import Foundation

extension String {

    func containsOnlyCharactersIn(_ matchCharacters: String) -> Bool {
        let disallowedCharacterSet = CharacterSet(charactersIn: matchCharacters).inverted
        return self.rangeOfCharacter(from: disallowedCharacterSet) == nil
    }
    
    
}
