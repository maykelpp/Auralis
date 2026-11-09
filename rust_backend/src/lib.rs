// Auralis Rust core starter. No Mornye code copied.
#[no_mangle]
pub extern "C" fn auralis_core_version() -> u32 { 1 }

pub fn milliseconds_to_seconds(ms: u64) -> u64 { ms / 1_000 }

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn converts_milliseconds() {
        assert_eq!(milliseconds_to_seconds(12_345), 12);
    }
}
