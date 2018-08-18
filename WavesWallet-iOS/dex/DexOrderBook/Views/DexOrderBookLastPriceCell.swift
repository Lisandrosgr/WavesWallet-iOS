//
//  DexOrderBookLastPriceCell.swift
//  WavesWallet-iOS
//
//  Created by Pavel Gubin on 8/16/18.
//  Copyright © 2018 Waves Platform. All rights reserved.
//

import UIKit

final class DexOrderBookLastPriceCell: UITableViewCell, Reusable {

    @IBOutlet weak var labelPrice: UILabel!
    @IBOutlet weak var labelSpread: UILabel!
    @IBOutlet weak var iconState: UIImageView!
    @IBOutlet weak var labelLastPrice: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        labelLastPrice.text = Localizable.DexOrderBook.Label.lastPrice
    }
}

extension DexOrderBookLastPriceCell: ViewConfiguration {
   
    func update(with model: DexOrderBook.DTO.LastPrice) {
        
        labelPrice.text = String(model.price)
        labelSpread.text = Localizable.DexOrderBook.Label.spread + " " + String(model.percent) + "%"
        iconState.image = model.orderType == .sell ? Images.chartarrow22Error500.image : Images.chartarrow22Success400.image
        
        // price = lastAsk - firstBid * 100 / lastAsk

        //        const [lastAsk] = asks;
        //        const [firstBid] = bids;

        //        const sell = new BigNumber(firstBid && firstBid.price);
        //        const buy = new BigNumber(lastAsk && lastAsk.price);

        //        const percent = (sell && buy && buy.gt(0)) ? buy.minus(sell).times(100).div(buy) : new BigNumber(0);
    }
   
}