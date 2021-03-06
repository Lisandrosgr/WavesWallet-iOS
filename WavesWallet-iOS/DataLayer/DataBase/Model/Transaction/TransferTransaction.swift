//
//  TransferTransaction.swift
//  WavesWallet-iOS
//
//  Created by mefilt on 19.07.2018.
//  Copyright © 2018 Waves Platform. All rights reserved.
//

import Foundation
import Gloss
import RealmSwift
import Realm
import RxDataSources

public class TransferTransaction: Transaction {
    @objc dynamic var amount: Int64 = 0
    @objc dynamic var assetId: String?
    @objc dynamic var recipient: String = ""
    @objc dynamic var attachment: String?

    public required init?(json: JSON) {
        guard let amount: Int64 = "amount" <~~ json,
            let recipient: String = "recipient" <~~ json else {
                return nil
        }

        self.amount = amount
        self.assetId = "assetId" <~~ json
        self.recipient = recipient
        self.attachment = "attachment" <~~ json

        super.init(json: json)
    }

    required public init() {
        super.init()
    }

    /**
     WARNING: This is an internal initializer not intended for public use.
     :nodoc:
     */
    public required init(realm: RLMRealm, schema: RLMObjectSchema) {
        super.init(realm: realm, schema: schema)
    }

    public required init(value: Any, schema: RLMSchema) {
        super.init(value: value, schema: schema)
    }

    public override func getAssetId() -> String {
        return assetId ?? ""
    }

    public override func getAmount() -> Int64 {
        return amount
    }

    public override func getCounterParty() -> String {
        return isInput() ? sender : recipient
    }
}
