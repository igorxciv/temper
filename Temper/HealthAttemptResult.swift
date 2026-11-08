/// The one line the timing log gets for an attempt at saving a Health workout, or for a pending save dropped once
/// writing isn't allowed.
enum HealthAttemptResult: String {
    case saved
    case unverified
    case failed
    /// The pending save was removed without being confirmed: Health refused it as not allowed, or it used up its
    /// last attempt.
    case dropped
}
