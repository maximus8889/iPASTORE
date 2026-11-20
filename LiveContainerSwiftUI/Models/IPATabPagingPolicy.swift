import Foundation

enum IPATabPagingPolicy {
    static let transitionDuration: TimeInterval = 0.30
    static func acceptsPan(velocityX: CGFloat, velocityY: CGFloat, translationX: CGFloat, translationY: CGFloat) -> Bool {
        guard [velocityX, velocityY, translationX, translationY].allSatisfy(\.isFinite) else { return false }
        // Direction, rather than a speed floor, admits deliberate slow drags.
        // Clear horizontal intent preserves vertical lists and nested shelves.
        if abs(velocityX) + abs(velocityY) > 5 { return abs(velocityX) > abs(velocityY) * 2.2 }
        return abs(translationX) > 4 && abs(translationX) > abs(translationY) * 2.2
    }
    static func direction(velocity: CGFloat, translation: CGFloat) -> Int? {
        guard velocity.isFinite, translation.isFinite else { return nil }
        let movement = abs(velocity) > 5 ? velocity : translation
        guard movement != 0 else { return nil }
        return movement < 0 ? 1 : -1
    }
    static func adjacent(to index: Int, direction: Int, count: Int) -> Int? {
        guard abs(direction) == 1, (0..<count).contains(index), (0..<count).contains(index + direction) else { return nil }
        return index + direction
    }
    static func progress(distance: CGFloat, width: CGFloat, direction: Int) -> CGFloat {
        guard width > 0, width.isFinite, distance.isFinite, abs(direction) == 1 else { return 0 }
        return min(1, max(0, -CGFloat(direction) * distance / width))
    }
    static func commits(distance: CGFloat, velocity: CGFloat, width: CGFloat, direction: Int) -> Bool {
        guard width > 0, width.isFinite, distance.isFinite, velocity.isFinite, abs(direction) == 1 else { return false }
        let towards = -CGFloat(direction) * velocity
        if towards < -350 { return false }
        let value = progress(distance: distance, width: width, direction: direction)
        if towards > 650 && value > 0.04 { return true }
        return value > 0.35 || progress(distance: distance + velocity * 0.16, width: width, direction: direction) > 0.5
    }
    static func completionSpeed(progress: CGFloat, completed: Bool) -> CGFloat {
        guard progress.isFinite else { return 1 }
        // UIKit already scales completion by the distance still to travel.
        // A progress-dependent minimum duration slowed nearly finished drags.
        // Keep one positive rate for finish/cancel, independent of hold time.
        return 2.2
    }
}
