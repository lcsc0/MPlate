//
//  MenuModels.swift
//  MPlate
//
//  Unified JSON decoding structs for the U-M Dining API.
//

import Foundation

let hallNames = [
    "Mosher Jordan Dining Hall",
    "Markley Dining Hall",
    "Bursley Dining Hall",
    "South Quad Dining Hall",
    "East Quad Dining Hall",
    "Twigs at Oxford",
    "North Quad Dining Hall",
    "Martha Cook Dining Hall",
    "Lawyers Club Dining Hall"
]

struct CustomItemRow {
    let id: Int64
    let name: String
    let kcal: String
    let pro: String
    let fat: String
    let cho: String
    let serving: String
}

// MARK: - JSON decoding

struct apiCalled: Codable {
    var menu: Menu?
}

struct Menu: Codable {
    var meal: [Meal]?
}

struct Meal: Codable {
    var name: String?
    var course: CourseWrapper?

    struct CourseWrapper: Codable {
        var courseitem: [Course]

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let singleCourseItem = try? container.decode(Course.self) {
                courseitem = [singleCourseItem]
            } else if let multipleItems = try? container.decode([Course].self) {
                courseitem = multipleItems
            } else {
                throw DecodingError.typeMismatch(
                    CourseWrapper.self,
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Expected single MenuItem or array of MenuItem."
                    )
                )
            }
        }

        struct Course: Codable {
            var name: String?
            var menuitem: ItemWrapper

            struct ItemWrapper: Codable {
                var item: [MenuItem]

                init(from decoder: Decoder) throws {
                    let container = try decoder.singleValueContainer()
                    if let singleItem = try? container.decode(MenuItem.self) {
                        item = [singleItem]
                    } else if let multipleItems = try? container.decode([MenuItem].self) {
                        item = multipleItems
                    } else {
                        throw DecodingError.typeMismatch(
                            ItemWrapper.self,
                            DecodingError.Context(
                                codingPath: decoder.codingPath,
                                debugDescription: "Expected single MenuItem or array of MenuItem."
                            )
                        )
                    }
                }

                func encode(to encoder: Encoder) throws {
                    var container = encoder.singleValueContainer()
                    if item.count == 1 {
                        try container.encode(item[0])
                    } else {
                        try container.encode(item)
                    }
                }
            }

            struct MenuItem: Codable {
                var name: String?
                var itemsize: ItemSize?
            }
        }
    }
}

// MARK: - Nutrition

struct Nutrition: Codable {
    var pro: String?
    var fat: String?
    var cho: String?
    var kcal: String?
    var fiber: String?        // tdfb
    var sodium: String?       // na
    var sugar: String?        // sugar
    var satFat: String?       // sfa
    var cholesterol: String?  // chol
    var calcium: String?      // ca
    var iron: String?         // fe
    var vitC: String?         // vitc
    var vitD: String?         // vitd
    var potassium: String?    // k

    init(from nutritionDict: [String: String]? = nil) {
        self.pro = nutritionDict?["pro"] ?? "0gm"
        self.fat = nutritionDict?["fat"] ?? "0gm"
        self.cho = nutritionDict?["cho"] ?? "0gm"
        self.kcal = nutritionDict?["kcal"] ?? "0kcal"
        self.fiber       = nutritionDict?["tdfb"]
        self.sodium      = nutritionDict?["na"]
        self.sugar       = nutritionDict?["sugar"]
        self.satFat      = nutritionDict?["sfa"]
        self.cholesterol = nutritionDict?["chol"]
        self.calcium     = nutritionDict?["ca"]
        self.iron        = nutritionDict?["fe"]
        self.vitC        = nutritionDict?["vitc"]
        self.vitD        = nutritionDict?["vitd"]
        self.potassium   = nutritionDict?["k"]
    }
}

// MARK: - ItemSize

struct ItemSize: Codable {
    var serving_size: String?
    var portion_size: String?
    var nutrition: Nutrition?

    enum CodingKeys: String, CodingKey {
        case serving_size
        case portion_size
        case nutrition
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.serving_size = try? container.decode(String.self, forKey: .serving_size)
        self.portion_size = try? container.decode(String.self, forKey: .portion_size)

        if let nutritionDict = try? container.decode([String: String].self, forKey: .nutrition) {
            self.nutrition = Nutrition(from: nutritionDict)
        } else if let nutritionArray = try? container.decode([String].self, forKey: .nutrition), nutritionArray.isEmpty {
            self.nutrition = Nutrition()
        } else {
            self.nutrition = Nutrition()
        }
    }
}
