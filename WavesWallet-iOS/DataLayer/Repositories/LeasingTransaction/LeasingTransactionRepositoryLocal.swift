//
//  LeasingTransactionRepositoryLocal.swift
//  WavesWallet-iOS
//
//  Created by Prokofev Ruslan on 05/08/2018.
//  Copyright © 2018 Waves Platform. All rights reserved.
//

import Foundation
import RxSwift
import RxRealm
import RealmSwift

final class LeasingTransactionRepositoryLocal: LeasingTransactionRepositoryProtocol {

    func activeLeasingTransactions(by accountAddress: String) -> AsyncObservable<[DomainLayer.DTO.LeasingTransaction]> {
        return Observable.create({ (observer) -> Disposable in

            guard let realm = try? Realm() else {
                observer.onError(LeasingTransactionRepositoryError.fail)
                return Disposables.create()
            }

            let objects = realm.objects(LeasingTransaction.self)
                .toArray()
                .map { DomainLayer.DTO.LeasingTransaction(transaction: $0) }

            observer.onNext(objects)
            observer.onCompleted()

            return Disposables.create()
        })
    }

    func saveLeasingTransactions(_ transactions:[DomainLayer.DTO.LeasingTransaction]) -> Observable<Bool> {
        return Observable.create({ (observer) -> Disposable in

            guard let realm = try? Realm() else {
                observer.onNext(false)
                observer.onError(LeasingTransactionRepositoryError.fail)
                return Disposables.create()
            }

            do {
                try realm.write({
                    realm.add(transactions.map { LeasingTransaction(transaction: $0) }, update: true)
                })
                observer.onNext(true)
                observer.onCompleted()
            } catch _ {
                observer.onNext(false)
                observer.onError(LeasingTransactionRepositoryError.fail)
                return Disposables.create()
            }

            return Disposables.create()
        })
    }

    func saveLeasingTransaction(_ transaction: DomainLayer.DTO.LeasingTransaction) -> Observable<Bool> {
        return saveLeasingTransactions([transaction])
    }
}

