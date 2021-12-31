//
//  DrawTogether.swift
//  DrawTogether
//
//  Created by Wylan L Neely on 12/31/21.
//  Copyright © 2021 Apple. All rights reserved.
//

import Foundation
import GroupActivities

struct DrawTogether: GroupActivity {
    var metadata: GroupActivityMetadata {
        var metadata = GroupActivityMetadata()
        metadata.title = NSLocalizedString("Draw Together", comment: "Title of Group Activity")
        metadata.type = .generic
        return metadata
    }
}
