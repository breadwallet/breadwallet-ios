// 
//  IntentHandler.swift
//  breadwalletIntentHandler
//
//  Created by stringcode on 11/02/2021.
//  Copyright © 2021 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import Intents

class IntentHandler: INExtension {

    private let service: WidgetService

    override init() {
        service = DefaultWidgetService(widgetDataShareService: nil,
                                       imageStoreService: nil)
        super.init()
    }

    override func handler(for intent: INIntent) -> Any {
        return self
    }
}

// MARK: - AssetIntentHandling

extension IntentHandler: AssetIntentHandling {
        
    func provideChartUpColorOptionsCollection(for intent: AssetIntent, with completion: @escaping (INObjectCollection<ColorOption>?, Error?) -> Void) {
        service.fetchChartUpColorOptions { result in
            switch result {
            case let .success(options):
                let collection = INObjectCollection(
                    sections: [
                        INObjectSection(title: S.Widget.colorSectionBasic,
                                        items: options.filter { $0.isBasicColor }),
                        INObjectSection(title: S.Widget.colorSectionText,
                                        items: options.filter { $0.isBrdTextColor }),
                        INObjectSection(title: S.Widget.colorSectionBackground,
                                        items: options.filter { $0.isBrdBackgroundColor })
                    ]
                )
                completion(collection, nil)
            case let .failure(error):
                print("Failed to chart up color options", error)
                completion(INObjectCollection(items: []), error)
            }
        }
    }
    
    func defaultChartUpColor(for intent: AssetIntent) -> ColorOption? {
        return service.defaultChartUpOptions()
    }
    
    func provideChartDownColorOptionsCollection(for intent: AssetIntent, with completion: @escaping (INObjectCollection<ColorOption>?, Error?) -> Void) {
        service.fetchChartDownColorOptions { result in
            switch result {
            case let .success(options):
                let collection = INObjectCollection(
                    sections: [
                        INObjectSection(title: S.Widget.colorSectionBasic,
                                        items: options.filter { $0.isBasicColor }),
                        INObjectSection(title: S.Widget.colorSectionText,
                                        items: options.filter { $0.isBrdTextColor }),
                        INObjectSection(title: S.Widget.colorSectionBackground,
                                        items: options.filter { $0.isBrdBackgroundColor })
                    ]
                )
                completion(collection, nil)
            case let .failure(error):
                print("Failed to chart up color options", error)
                completion(INObjectCollection(items: []), error)
            }
        }
    }
    
    func defaultChartDownColor(for intent: AssetIntent) -> ColorOption? {
        return service.defaultChartDownOptions()
    }
    
    func provideBackgroundColorOptionsCollection(for intent: AssetIntent, with completion: @escaping (INObjectCollection<ColorOption>?, Error?) -> Void) {
        service.fetchBackgroundColorOptions { result in
            switch result {
            case let .success(options):
                let collection = INObjectCollection(
                    sections: [
                        INObjectSection(title: S.Widget.colorSectionSystem,
                                        items: options.filter { $0.isSystem }),
                        INObjectSection(title: S.Widget.colorSectionBackground,
                                        items: options.filter { $0.isBrdBackgroundColor }),
                        INObjectSection(title: S.Widget.colorSectionBasic,
                                        items: options.filter { $0.isBasicColor }),
                        INObjectSection(title: S.Widget.colorSectionCurrency,
                                        items: options.filter { $0.isCurrencyColor })
                    ]

                )
                completion(collection, nil)
            case let .failure(error):
                print("Failed to chart up color options", error)
                completion(INObjectCollection(items: []), error)
            }
        }
    }
    
    func defaultBackgroundColor(for intent: AssetIntent) -> ColorOption? {
        return service.defaultBackgroundColor()
    }
    
    func provideTextColorOptionsCollection(for intent: AssetIntent, with completion: @escaping (INObjectCollection<ColorOption>?, Error?) -> Void) {
        service.fetchTextColorOptions { result in
            switch result {
            case let .success(options):
                let collection = INObjectCollection(
                    sections: [
                        INObjectSection(title: S.Widget.colorSectionSystem,
                                        items: options.filter { $0.isSystem }),
                        INObjectSection(title: S.Widget.colorSectionText,
                                        items: options.filter { $0.isBrdTextColor }),
                        INObjectSection(title: S.Widget.colorSectionBasic,
                                        items: options.filter { $0.isBasicColor }),
                        INObjectSection(title: S.Widget.colorSectionBackground,
                                        items: options.filter { $0.isBrdBackgroundColor })
                    ]
                )
                completion(collection, nil)
            case let .failure(error):
                print("Failed to chart up color options", error)
                completion(INObjectCollection(items: []), error)
            }
        }
    }
    
    func defaultTextColor(for intent: AssetIntent) -> ColorOption? {
        return service.defaultTextColor()
    }
    
    func provideAssetOptionsCollection(for intent: AssetIntent, with completion: @escaping (INObjectCollection<AssetOption>?, Error?) -> Void) {

        service.fetchAssetOptions { result in
            switch result {
            case let .success(options):
                completion(INObjectCollection(items: options), nil)
            case let .failure(error):
                print("Failed to load asset options", error)
                completion(INObjectCollection(items: []), error)
            }
        }
    }

    func defaultAsset(for intent: AssetIntent) -> AssetOption? {
        return service.defaultAssetOptions().first
            
    }
}

// MARK: - AssetListIntentHandling

extension IntentHandler: AssetListIntentHandling {
    
    func provideAssetsOptionsCollection(for intent: AssetListIntent, with completion: @escaping (INObjectCollection<AssetOption>?, Error?) -> Void) {
        service.fetchAssetOptions { result in
            switch result {
            case let .success(options):
                completion(INObjectCollection(items: options), nil)
            case let .failure(error):
                print("Failed to load asset options", error)
                completion(INObjectCollection(items: []), error)
            }
        }
    }

    func defaultAssets(for intent: AssetListIntent) -> [AssetOption]? {
        return service.defaultAssetOptions()
    }

    func provideChartUpColorOptionsCollection(for intent: AssetListIntent, with completion: @escaping (INObjectCollection<ColorOption>?, Error?) -> Void) {
        service.fetchChartUpColorOptions { result in
            switch result {
            case let .success(options):
                let collection = INObjectCollection(
                    sections: [
                        INObjectSection(title: S.Widget.colorSectionBasic,
                                        items: options.filter { $0.isBasicColor }),
                        INObjectSection(title: S.Widget.colorSectionText,
                                        items: options.filter { $0.isBrdTextColor }),
                        INObjectSection(title: S.Widget.colorSectionBackground,
                                        items: options.filter { $0.isBrdBackgroundColor })
                    ]
                )
                completion(collection, nil)
            case let .failure(error):
                print("Failed to chart up color options", error)
                completion(INObjectCollection(items: []), error)
            }
        }
    }

    func defaultChartUpColor(for intent: AssetListIntent) -> ColorOption? {
        return service.defaultChartUpOptions()
    }

    func provideChartDownColorOptionsCollection(for intent: AssetListIntent, with completion: @escaping (INObjectCollection<ColorOption>?, Error?) -> Void) {
        service.fetchChartDownColorOptions { result in
            switch result {
            case let .success(options):
                let collection = INObjectCollection(
                    sections: [
                        INObjectSection(title: S.Widget.colorSectionBasic,
                                        items: options.filter { $0.isBasicColor }),
                        INObjectSection(title: S.Widget.colorSectionText,
                                        items: options.filter { $0.isBrdTextColor }),
                        INObjectSection(title: S.Widget.colorSectionBackground,
                                        items: options.filter { $0.isBrdBackgroundColor })
                    ]
                )
                completion(collection, nil)
            case let .failure(error):
                print("Failed to chart up color options", error)
                completion(INObjectCollection(items: []), error)
            }
        }
    }

    func defaultChartDownColor(for intent: AssetListIntent) -> ColorOption? {
        return service.defaultChartDownOptions()
    }

    func provideBackgroundColorOptionsCollection(for intent: AssetListIntent, with completion: @escaping (INObjectCollection<ColorOption>?, Error?) -> Void) {
        service.fetchBackgroundColorOptions { result in
            switch result {
            case let .success(options):
                let collection = INObjectCollection(
                    sections: [
                        INObjectSection(title: S.Widget.colorSectionSystem,
                                        items: options.filter { $0.isSystem }),
                        INObjectSection(title: S.Widget.colorSectionBackground,
                                        items: options.filter { $0.isBrdBackgroundColor }),
                        INObjectSection(title: S.Widget.colorSectionBasic,
                                        items: options.filter { $0.isBasicColor }),
                        INObjectSection(title: S.Widget.colorSectionCurrency,
                                        items: options.filter { $0.isCurrencyColor })
                    ]
                )
                completion(collection, nil)
            case let .failure(error):
                print("Failed to chart up color options", error)
                completion(INObjectCollection(items: []), error)
            }
        }
    }

    func defaultBackgroundColor(for intent: AssetListIntent) -> ColorOption? {
        return service.defaultBackgroundColor()
    }

    func provideTextColorOptionsCollection(for intent: AssetListIntent, with completion: @escaping (INObjectCollection<ColorOption>?, Error?) -> Void) {
        service.fetchTextColorOptions { result in
            switch result {
            case let .success(options):
                let collection = INObjectCollection(
                    sections: [
                        INObjectSection(title: S.Widget.colorSectionSystem,
                                        items: options.filter { $0.isSystem }),
                        INObjectSection(title: S.Widget.colorSectionText,
                                        items: options.filter { $0.isBrdTextColor }),
                        INObjectSection(title: S.Widget.colorSectionBasic,
                                        items: options.filter { $0.isBasicColor }),
                        INObjectSection(title: S.Widget.colorSectionBackground,
                                        items: options.filter { $0.isBrdBackgroundColor })
                    ]
                )
                completion(collection, nil)
            case let .failure(error):
                print("Failed to chart up color options", error)
                completion(INObjectCollection(items: []), error)
            }
        }
    }

    func defaultTextColor(for intent: AssetListIntent) -> ColorOption? {
        return service.defaultTextColor()
    }
}

// MARK: - PortfolioIntentHandling

extension IntentHandler: PortfolioIntentHandling {
    
    func provideAssetsOptionsCollection(for intent: PortfolioIntent, with completion: @escaping (INObjectCollection<AssetOption>?, Error?) -> Void) {
        service.fetchAssetOptions { result in
            switch result {
            case let .success(options):
                completion(INObjectCollection(items: options), nil)
            case let .failure(error):
                print("Failed to load asset options", error)
                completion(INObjectCollection(items: []), error)
            }
        }
    }

    func defaultAssets(for intent: PortfolioIntent) -> [AssetOption]? {
        return service.defaultAssetOptions()
    }

    func provideChartUpColorOptionsCollection(for intent: PortfolioIntent, with completion: @escaping (INObjectCollection<ColorOption>?, Error?) -> Void) {
        service.fetchChartUpColorOptions { result in
            switch result {
            case let .success(options):
                let collection = INObjectCollection(
                    sections: [
                        INObjectSection(title: S.Widget.colorSectionBasic,
                                        items: options.filter { $0.isBasicColor }),
                        INObjectSection(title: S.Widget.colorSectionText,
                                        items: options.filter { $0.isBrdTextColor }),
                        INObjectSection(title: S.Widget.colorSectionBackground,
                                        items: options.filter { $0.isBrdBackgroundColor })
                    ]
                )
                completion(collection, nil)
            case let .failure(error):
                print("Failed to chart up color options", error)
                completion(INObjectCollection(items: []), error)
            }
        }
    }

    func defaultChartUpColor(for intent: PortfolioIntent) -> ColorOption? {
        return service.defaultChartUpOptions()
    }

    func provideChartDownColorOptionsCollection(for intent: PortfolioIntent, with completion: @escaping (INObjectCollection<ColorOption>?, Error?) -> Void) {
        service.fetchChartDownColorOptions { result in
            switch result {
            case let .success(options):
                let collection = INObjectCollection(
                    sections: [
                        INObjectSection(title: S.Widget.colorSectionBasic,
                                        items: options.filter { $0.isBasicColor }),
                        INObjectSection(title: S.Widget.colorSectionText,
                                        items: options.filter { $0.isBrdTextColor }),
                        INObjectSection(title: S.Widget.colorSectionBackground,
                                        items: options.filter { $0.isBrdBackgroundColor })
                    ]
                )
                completion(collection, nil)
            case let .failure(error):
                print("Failed to chart up color options", error)
                completion(INObjectCollection(items: []), error)
            }
        }
    }

    func defaultChartDownColor(for intent: PortfolioIntent) -> ColorOption? {
        return service.defaultChartDownOptions()
    }

    func provideBackgroundColorOptionsCollection(for intent: PortfolioIntent, with completion: @escaping (INObjectCollection<ColorOption>?, Error?) -> Void) {
        service.fetchBackgroundColorOptions { result in
            switch result {
            case let .success(options):
                let collection = INObjectCollection(
                    sections: [
                        INObjectSection(title: S.Widget.colorSectionSystem,
                                        items: options.filter { $0.isSystem }),
                        INObjectSection(title: S.Widget.colorSectionBackground,
                                        items: options.filter { $0.isBrdBackgroundColor }),
                        INObjectSection(title: S.Widget.colorSectionBasic,
                                        items: options.filter { $0.isBasicColor }),
                        INObjectSection(title: S.Widget.colorSectionCurrency,
                                        items: options.filter { $0.isCurrencyColor })
                    ]
                )
                completion(collection, nil)
            case let .failure(error):
                print("Failed to chart up color options", error)
                completion(INObjectCollection(items: []), error)
            }
        }
    }

    func defaultBackgroundColor(for intent: PortfolioIntent) -> ColorOption? {
        return service.defaultBackgroundColor()
    }

    func provideTextColorOptionsCollection(for intent: PortfolioIntent, with completion: @escaping (INObjectCollection<ColorOption>?, Error?) -> Void) {
        service.fetchTextColorOptions { result in
            switch result {
            case let .success(options):
                let collection = INObjectCollection(
                    sections: [
                        INObjectSection(title: S.Widget.colorSectionSystem,
                                        items: options.filter { $0.isSystem }),
                        INObjectSection(title: S.Widget.colorSectionText,
                                        items: options.filter { $0.isBrdTextColor }),
                        INObjectSection(title: S.Widget.colorSectionBasic,
                                        items: options.filter { $0.isBasicColor }),
                        INObjectSection(title: S.Widget.colorSectionBackground,
                                        items: options.filter { $0.isBrdBackgroundColor })
                    ]
                )
                completion(collection, nil)
            case let .failure(error):
                print("Failed to chart up color options", error)
                completion(INObjectCollection(items: []), error)
            }
        }
    }

    func defaultTextColor(for intent: PortfolioIntent) -> ColorOption? {
        return service.defaultTextColor()
    }
}
