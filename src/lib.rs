pub mod keyboard_helper;
pub mod simulator;

pub use keyboard_helper::KeyboardHelper;
pub use simulator::KeySimulator;

pub const DRIVER_LETTER_VAR_NAME: &str = "driveLetter";