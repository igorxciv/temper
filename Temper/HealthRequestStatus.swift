/// Whether asking for the full set of Health types would show the system sheet.
enum HealthRequestStatus {
    /// Some type in the set hasn't been asked about yet.
    case shouldRequest
    /// Every type in the set has been answered, or Health couldn't tell.
    case unnecessary
}
