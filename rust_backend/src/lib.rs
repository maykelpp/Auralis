//! Auralis native core placeholder. Audio playback and extension execution are
//! currently provided by the Flutter layer; this crate keeps a tested native
//! foundation without pretending an FFI bridge is already wired.

pub fn normalize_query(value: &str) -> String {
    value.split_whitespace().collect::<Vec<_>>().join(" ").to_lowercase()
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn normalizes_search_query() {
        assert_eq!(normalize_query("  Hello   MUSIC "), "hello music");
    }
}
