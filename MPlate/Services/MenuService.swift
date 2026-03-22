//
//  MenuService.swift
//  MPlate
//
//  Handles fetching dining hall menus from the U-M API and bundled JSON fallbacks.
//  Menus are cached in-memory per dining hall per day to avoid redundant network calls.
//

import Foundation

// MARK: - In-memory daily cache

final class MenuCache {
    static let shared = MenuCache()
    private init() {}

    private var store: [String: Menu] = [:]

    private func key(diningHall: String, date: String) -> String {
        "\(diningHall)|\(date)"
    }

    func get(diningHall: String) -> Menu? {
        let today = currentDateString()
        return store[key(diningHall: diningHall, date: today)]
    }

    func set(_ menu: Menu, for diningHall: String) {
        let today = currentDateString()
        store[key(diningHall: diningHall, date: today)] = menu
    }

    private func currentDateString() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }
}

// MARK: - URL builder

class APIHandling {
    static func getURL(diningHall: String) -> String {
        return "https://api.studentlife.umich.edu/menu/xml2print.php?controller=print&view=json&location=\(diningHall.replacingOccurrences(of: " ", with: "%20"))"
    }
}

// MARK: - Menu service

class MenuService {

    /// Fetch live menu from U-M API, falling back to bundled JSON on error.
    /// Results are cached per dining hall per day — the network is only hit once daily.
    static func fetchMenu(diningHall: String, completion: @escaping (Menu?, Bool) -> Void) {
        // Return cached result if available for today
        if let cached = MenuCache.shared.get(diningHall: diningHall) {
            DispatchQueue.main.async { completion(cached, false) }
            return
        }

        let urlString = APIHandling.getURL(diningHall: diningHall)
        guard let url = URL(string: urlString) else {
            completion(nil, false)
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            if error == nil, let data = data {
                do {
                    let itemFeed = try JSONDecoder().decode(apiCalled.self, from: data)
                    if let menu = itemFeed.menu {
                        MenuCache.shared.set(menu, for: diningHall)
                        DispatchQueue.main.async { completion(menu, false) }
                    } else {
                        let demo = loadDemoMenu(diningHall: diningHall)
                        DispatchQueue.main.async { completion(demo, true) }
                    }
                } catch {
                    print("Menu decode error: \(error)")
                    let demo = loadDemoMenu(diningHall: diningHall)
                    DispatchQueue.main.async { completion(demo, true) }
                }
            } else {
                let demo = loadDemoMenu(diningHall: diningHall)
                DispatchQueue.main.async { completion(demo, true) }
            }
        }.resume()
    }

    /// Load bundled JSON menu for a dining hall.
    static func loadDemoMenu(diningHall: String) -> Menu? {
        guard let path = Bundle.main.path(forResource: diningHall.replacingOccurrences(of: " ", with: "_"), ofType: "json") else {
            print("Demo JSON file not found.")
            return nil
        }
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let itemFeed = try JSONDecoder().decode(apiCalled.self, from: data)
            print("Demo data loaded successfully.")
            return itemFeed.menu
        } catch {
            print("Error loading demo data: \(error)")
            return nil
        }
    }

    /// Load the "Other" menu (non-daily items like condiments, beverages, etc.) from bundled JSON.
    static func loadOtherMenu(diningHall: String) -> Menu? {
        let resourceName = diningHall.replacingOccurrences(of: " ", with: "_") + "_other"
        guard let path = Bundle.main.path(forResource: resourceName, ofType: "json") else {
            print("Other menu JSON not found for \(diningHall)")
            return nil
        }
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let itemFeed = try JSONDecoder().decode(apiCalled.self, from: data)
            print("Other menu loaded for \(diningHall).")
            return itemFeed.menu
        } catch {
            print("Error loading other menu: \(error)")
            return nil
        }
    }

    /// Load the special/extras menu from bundled JSON.
    static func loadSpecialMenu() -> Menu? {
        guard let path = Bundle.main.path(forResource: "special_menu", ofType: "json") else {
            print("Special JSON file not found.")
            return nil
        }
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let itemFeed = try JSONDecoder().decode(apiCalled.self, from: data)
            print("Special data loaded successfully.")
            return itemFeed.menu
        } catch {
            print("Error loading special data: \(error)")
            return nil
        }
    }
}
