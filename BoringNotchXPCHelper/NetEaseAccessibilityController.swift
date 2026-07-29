//
//  NetEaseAccessibilityController.swift
//  BoringNotchXPCHelper
//

import AppKit
import ApplicationServices
import Foundation

enum NetEaseAccessibilityController {
    private static let bundleIdentifier = "com.netease.163music"
    private static let maximumElementsToInspect = 1_500

    private static let favoriteTitles = [
        "添加到我喜欢的音乐",
        "喜欢",
        "收藏",
        "Love",
        "Favorite"
    ]

    private static let unfavoriteTitles = [
        "从我喜欢的音乐中移除",
        "取消喜欢",
        "取消收藏",
        "Unlove",
        "Remove from Favorites"
    ]

    static var favoriteState: Bool? {
        guard let application = applicationElement else { return nil }
        if findMenuItem(in: application, titles: unfavoriteTitles) != nil {
            return true
        }
        if findMenuItem(in: application, titles: favoriteTitles) != nil {
            return false
        }
        return nil
    }

    static func setFavorite(_ favorite: Bool) -> Bool {
        guard let application = applicationElement else { return false }
        let titles = favorite ? favoriteTitles : unfavoriteTitles
        guard let item = findMenuItem(in: application, titles: titles) else {
            return false
        }
        return AXUIElementPerformAction(item, kAXPressAction as CFString) == .success
    }

    static var volume: Double? {
        guard let slider = volumeSlider else { return nil }
        return (attribute(kAXValueAttribute as CFString, of: slider) as? NSNumber)?.doubleValue
    }

    static func setVolume(_ value: Double) -> Bool {
        guard let slider = volumeSlider else { return false }
        let clampedValue = max(0, min(1, value))
        return AXUIElementSetAttributeValue(
            slider,
            kAXValueAttribute as CFString,
            NSNumber(value: clampedValue)
        ) == .success
    }

    private static var applicationElement: AXUIElement? {
        guard AXIsProcessTrusted(),
              let application = NSRunningApplication.runningApplications(
                withBundleIdentifier: bundleIdentifier
              ).first
        else { return nil }
        return AXUIElementCreateApplication(application.processIdentifier)
    }

    private static var volumeSlider: AXUIElement? {
        guard let application = applicationElement else { return nil }

        return firstElement(in: application) { element in
            guard stringAttribute(kAXRoleAttribute as CFString, of: element)
                    == kAXSliderRole as String
            else { return false }

            let searchableAttributes = [
                kAXTitleAttribute,
                kAXDescriptionAttribute,
                kAXHelpAttribute,
                kAXIdentifierAttribute
            ]

            let searchableText = searchableAttributes.compactMap {
                stringAttribute($0 as CFString, of: element)
            }.joined(separator: " ").lowercased()

            return searchableText.contains("音量") || searchableText.contains("volume")
        }
    }

    private static func findMenuItem(
        in application: AXUIElement,
        titles: [String]
    ) -> AXUIElement? {
        firstElement(in: application) { element in
            guard stringAttribute(kAXRoleAttribute as CFString, of: element)
                    == kAXMenuItemRole as String,
                  let title = stringAttribute(kAXTitleAttribute as CFString, of: element)
            else { return false }

            return titles.contains {
                title.compare($0, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
            }
        }
    }

    private static func firstElement(
        in root: AXUIElement,
        matching predicate: (AXUIElement) -> Bool
    ) -> AXUIElement? {
        var queue = [root]
        var index = 0

        while index < queue.count && index < maximumElementsToInspect {
            let element = queue[index]
            index += 1

            if predicate(element) {
                return element
            }

            if let children = attribute(
                kAXChildrenAttribute as CFString,
                of: element
            ) as? [AXUIElement] {
                queue.append(contentsOf: children)
            }
        }

        return nil
    }

    private static func stringAttribute(
        _ name: CFString,
        of element: AXUIElement
    ) -> String? {
        attribute(name, of: element) as? String
    }

    private static func attribute(
        _ name: CFString,
        of element: AXUIElement
    ) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name, &value) == .success else {
            return nil
        }
        return value
    }
}
