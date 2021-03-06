//
//  AccountBalanceInteractor.swift
//  WavesWallet-iOS
//
//  Created by mefilt on 10.07.2018.
//  Copyright © 2018 Waves Platform. All rights reserved.
//

import Foundation
import Moya
import RealmSwift
import RxSwift
import RxSwiftExt

private enum Constants {
    static let durationInseconds: Double = 6000
}

protocol AccountBalanceInteractorProtocol {

    func balances(by accountAddress: String,
                  privateKey: PrivateKeyAccount,
                  isNeedUpdate: Bool) -> Observable<[DomainLayer.DTO.AssetBalance]>    
}

final class AccountBalanceInteractor: AccountBalanceInteractorProtocol {

    private let balanceRepositoryLocal: AccountBalanceRepositoryProtocol = FactoryRepositories.instance.accountBalanceRepositoryLocal
    private let balanceRepositoryRemote: AccountBalanceRepositoryProtocol = FactoryRepositories.instance.accountBalanceRepositoryRemote

    private let assetsInteractor: AssetsInteractorProtocol = FactoryInteractors.instance.assetsInteractor
    private let leasingInteractor: LeasingInteractorProtocol = FactoryInteractors.instance.leasingInteractor

    private let disposeBag: DisposeBag = DisposeBag()

    func balances(by accountAddress: String,
                  privateKey: PrivateKeyAccount,
                  isNeedUpdate: Bool = false) -> Observable<[DomainLayer.DTO.AssetBalance]> {

        return self.balanceRepositoryLocal
            .balances(by: accountAddress, privateKey: privateKey)
            .flatMap(weak: self) { owner, balances -> Observable<[DomainLayer.DTO.AssetBalance]> in

                let now = Date()
                let isNeedForceUpdate = balances.count == 0 || balances.first { (now.timeIntervalSinceNow - $0.modified.timeIntervalSinceNow) > Constants.durationInseconds } != nil || isNeedUpdate

                if isNeedForceUpdate {
                    info("From Remote", type: AssetsInteractor.self)
                } else {
                    info("From BD", type: AssetsInteractor.self)
                }
                guard isNeedForceUpdate == true else { return Observable.just(balances) }

                return owner.remoteBalances(accountAddress: accountAddress,
                                            privateKey: privateKey,
                                            localBalance: balances,
                                            isNeedUpdate: isNeedForceUpdate)
            }
            .share()
            .observeOn(ConcurrentDispatchQueueScheduler(queue: DispatchQueue.global()))
    }
}


// MARK: Privet methods

private extension AccountBalanceInteractor {

    private func remoteBalances(accountAddress: String,
                                privateKey: PrivateKeyAccount,
                                localBalance: [DomainLayer.DTO.AssetBalance],
                                isNeedUpdate: Bool) -> Observable<[DomainLayer.DTO.AssetBalance]> {

        let balances = balanceRepositoryRemote.balances(by: accountAddress,
                                                        privateKey: privateKey)
        let activeTransactions = leasingInteractor.activeLeasingTransactions(by: accountAddress, isNeedUpdate: isNeedUpdate)

        return Observable.zip(balances, activeTransactions)
            .map { balances, transactions -> [DomainLayer.DTO.AssetBalance] in

                let generalBalances = Environments.current.generalAssetIds.map { DomainLayer.DTO.AssetBalance(info: $0) }
                var newList = balances
                for generalBalance in generalBalances {
                    if balances.contains(where: { $0.assetId == generalBalance.assetId }) == false {
                        newList.append(generalBalance)
                    }
                }

                if let pair = newList.enumerated().first(where: { $0.element.assetId == Environments.Constants.wavesAssetId }) {
                    let newBalance = pair.element.mutate { balance in
                        balance.leasedBalance = transactions
                            .filter { $0.sender == accountAddress }
                            .reduce(0) { $0 + $1.amount }
                    }
                    newList[pair.offset] = newBalance
                }
                return newList
            }
            .flatMap(weak: self) { owner, balances -> Observable<[DomainLayer.DTO.AssetBalance]> in

                let ids = balances.map { $0.assetId }
                return owner
                    .assetsInteractor
                    .assets(by: ids, accountAddress: accountAddress, isNeedUpdated: isNeedUpdate)
                    .flatMap(weak: owner) { (owner, assets) -> Observable<[DomainLayer.DTO.AssetBalance]> in
                        let mapAssets = assets.reduce([String: DomainLayer.DTO.Asset]()) {
                            var map = $0
                            map[$1.id] = $1
                            return map
                        }

                        let oldSettings = localBalance.reduce([String: DomainLayer.DTO.AssetBalance.Settings]()) {
                            var map = $0
                            if let settings = $1.settings {
                                map[settings.assetId] = settings
                            }
                            return map
                        }

                        var newBalances = balances
                        for (index, balance) in newBalances.enumerated() {
                            newBalances[index].asset = mapAssets[balance.assetId]
                            newBalances[index].settings = oldSettings[balance.assetId]
                        }
                        newBalances = owner.initialSettings(for: newBalances)
                        return owner
                            .balanceRepositoryLocal
                            .saveBalances(newBalances)
                            .map { _ in newBalances }
                    }
            }
    }

    func initialSettings(for balances: [DomainLayer.DTO.AssetBalance]) -> [DomainLayer.DTO.AssetBalance] {

        let generalBalances = Environments
            .current
            .generalAssetIds

        var newBalances = balances
            .filter { $0.settings == nil }
            .sorted { assetOne, assetTwo -> Bool in

                let isGeneralOne = assetOne.asset?.isGeneral ?? false
                let isGeneralTwo = assetTwo.asset?.isGeneral ?? false

                if isGeneralOne == true && isGeneralTwo == true {
                    let indexOne = generalBalances
                        .enumerated()
                        .first(where: { $0.element.assetId == assetOne.assetId })
                        .map { $0.offset }

                    let indexTwo = generalBalances
                        .enumerated()
                        .first(where: { $0.element.assetId == assetTwo.assetId })
                        .map { $0.offset }

                    if let indexOne = indexOne, let indexTwo = indexTwo {
                        return indexOne < indexTwo
                    }
                    return false
                }

                if isGeneralOne {
                    return true
                }
                return false
            }

        let oldBalances = balances
            .filter { $0.settings != nil }
            .sorted { $0.settings!.sortLevel < $1.settings!.sortLevel }

        let lastSortLevel = oldBalances.last?.settings?.sortLevel ?? 0

        for (index, balance) in newBalances.enumerated() {

            let assetId = balance.assetId
            let sortLevel = lastSortLevel + Float(index)
            let isFavorite: Bool = balance.asset?.isWaves ?? false

            var newBalance = balance
            newBalance.settings = DomainLayer.DTO.AssetBalance.Settings(assetId: assetId,
                                                                        sortLevel: sortLevel,
                                                                        isHidden: false,
                                                                        isFavorite: isFavorite)
            newBalances[index] = newBalance
        }

        var newList = newBalances
        newList.append(contentsOf: oldBalances)
        return newList
    }
}

// MARK: Mapper

private extension DomainLayer.DTO.AssetBalance {

    init(info: Environment.AssetInfo) {
        self.assetId = info.assetId
        self.balance = 0
        self.leasedBalance = 0
        self.inOrderBalance = 0
        self.settings = nil
        self.asset = nil
        self.modified = Date()
    }
}
