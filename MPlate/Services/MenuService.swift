//
//  MenuService.swift
//  MPlate
//
//  Handles fetching dining hall menus from the U-M API and bundled JSON fallbacks.
//

import Foundation

class APIHandling {
    static func getURL(diningHall: String) -> String {
        return "https://api.studentlife.umich.edu/menu/xml2print.php?controller=print&view=json&location=\(diningHall.replacingOccurrences(of: " ", with: "%20"))"
    }
}

class MenuService {

    /// Fetch live menu from U-M API, falling back to bundled JSON on error.
    static func fetchMenu(diningHall: String, completion: @escaping (Menu?, Bool) -> Void) {
        let urlString = APIHandling.getURL(diningHall: diningHall)

        guard let url = URL(string: urlString) else {
            completion(nil, false)
            return
        }

        let session = URLSession.shared
        let dataTask = session.dataTask(with: url) { (data, response, error) in
            if error == nil, let data = data {
                let decoder = JSONDecoder()
                do {
                    let itemFeed = try decoder.decode(apiCalled.self, from: data)
                    DispatchQueue.main.async {
                        completion(itemFeed.menu, false)
                    }
                } catch {
                    print("error: \(error)")
                    let demoMenu = loadDemoMenu(diningHall: diningHall)
                    DispatchQueue.main.async {
                        completion(demoMenu, true)
                    }
                }
            } else {
                let demoMenu = loadDemoMenu(diningHall: diningHall)
                DispatchQueue.main.async {
                    completion(demoMenu, true)
                }
            }
        }
        dataTask.resume()
    }

    /// Load bundled JSON menu for a dining hall.
    static func loadDemoMenu(diningHall: String) -> Menu? {
        guard let path = Bundle.main.path(forResource: diningHall.replacingOccurrences(of: " ", with: "_"), ofType: "json") else {
            print("Demo JSON file not found.")
            return nil
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let decoder = JSONDecoder()
            let itemFeed = try decoder.decode(apiCalled.self, from: data)
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
            let decoder = JSONDecoder()
            let itemFeed = try decoder.decode(apiCalled.self, from: data)
            print("Other menu loaded successfully for \(diningHall).")
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
            let decoder = JSONDecoder()
            let itemFeed = try decoder.decode(apiCalled.self, from: data)
            print("Special data loaded successfully.")
            return itemFeed.menu
        } catch {
            print("Error loading special data: \(error)")
            return nil
        }
    }
}
